// tests/fixtures/optical/main.cc
// Optical-photon variant of geant4_claude_main.cc. Identical structure;
// differs only in: (1) FTFP_BERT + G4OpticalPhysics, (2) the SD records
// one Hits row per optical photon (pdg = -22) at its first step,
// (3) a runtime RINDEX guard before the run.
//
// Init-order contract: main does NOT call runManager->Initialize();
// the macro owns /run/initialize.

#include "G4RunManagerFactory.hh"
#include "G4UImanager.hh"
#include "G4VUserDetectorConstruction.hh"
#include "G4VUserActionInitialization.hh"
#include "G4VUserPrimaryGeneratorAction.hh"
#include "G4UserRunAction.hh"
#include "G4UserEventAction.hh"
#include "G4ParticleGun.hh"
#include "G4Event.hh"
#include "G4Run.hh"
#include "G4LogicalVolume.hh"
#include "G4LogicalVolumeStore.hh"
#include "G4Material.hh"
#include "G4MaterialPropertiesTable.hh"
#include "G4VPhysicalVolume.hh"
#include "G4SDManager.hh"
#include "G4VSensitiveDetector.hh"
#include "G4Step.hh"
#include "G4Track.hh"
#include "G4OpticalPhoton.hh"
#include "G4SystemOfUnits.hh"
#include "G4GDMLParser.hh"
#include "FTFP_BERT.hh"
#include "G4OpticalPhysics.hh"

#include "TFile.h"
#include "TTree.h"

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

namespace g4c {

struct EventBuffer {
  int                       event_id = -1;
  std::vector<std::string>  volume;
  std::vector<double>       edep;
  std::vector<double>       x, y, z, t;
  std::vector<int>          pdg;
  void clear() {
    volume.clear(); edep.clear();
    x.clear(); y.clear(); z.clear(); t.clear();
    pdg.clear();
  }
};
static EventBuffer gBuf;

constexpr int kVolumeNameMax = 64;

struct OutputState {
  std::unique_ptr<TFile> file;
  TTree*                 tree = nullptr;
  Int_t    event_id = 0;
  Int_t    pdg = 0;
  Double_t edep = 0., x = 0., y = 0., z = 0., t = 0.;
  char     volume[kVolumeNameMax] = {0};
};
static OutputState gOut;

// Optical-photon SD: record one Hits row per optical photon at its
// first step inside a sensitive volume. Counts each photon once per
// entry into a sensitive volume; a photon absorbed before taking a
// step in a sensitive volume is not counted (negligible here — the
// radiator has no ABSLENGTH and photons are born well inside it).
class OpticalSD : public G4VSensitiveDetector {
public:
  explicit OpticalSD(const G4String& name) : G4VSensitiveDetector(name) {}

  G4bool ProcessHits(G4Step* step, G4TouchableHistory*) override {
    const auto* track = step->GetTrack();
    if (track->GetDefinition() != G4OpticalPhoton::Definition())
      return false;
    if (track->GetCurrentStepNumber() != 1) return false;  // count once

    const auto& pos  = step->GetPreStepPoint()->GetPosition();
    const auto  time = step->GetPreStepPoint()->GetGlobalTime();
    const auto* lv   = step->GetPreStepPoint()
                           ->GetTouchableHandle()
                           ->GetVolume()
                           ->GetLogicalVolume();
    gBuf.volume.push_back(lv->GetName());
    gBuf.edep.push_back(0.0);
    gBuf.x.push_back(pos.x() / mm);
    gBuf.y.push_back(pos.y() / mm);
    gBuf.z.push_back(pos.z() / mm);
    gBuf.t.push_back(time / ns);
    gBuf.pdg.push_back(track->GetDefinition()->GetPDGEncoding());  // -22
    return true;
  }
};

class DetectorConstruction : public G4VUserDetectorConstruction {
public:
  explicit DetectorConstruction(G4String gdmlPath)
    : fGdmlPath(std::move(gdmlPath)) {}

  G4VPhysicalVolume* Construct() override {
    fParser.Read(fGdmlPath);
    return fParser.GetWorldVolume();
  }

  void ConstructSDandField() override {
    auto* lvs = G4LogicalVolumeStore::GetInstance();
    auto* sdm = G4SDManager::GetSDMpointer();
    int n_attached = 0;
    for (auto* lv : *lvs) {
      const auto& aux = fParser.GetVolumeAuxiliaryInformation(lv);
      bool sensitive = false;
      for (const auto& a : aux)
        if (a.type == "sensitive" && (a.value == "true" || a.value == "1")) {
          sensitive = true; break;
        }
      if (!sensitive) continue;
      auto* sd = new OpticalSD("SD/" + lv->GetName());
      sdm->AddNewDetector(sd);
      lv->SetSensitiveDetector(sd);
      ++n_attached;
    }
    G4cout << "[g4c] attached optical SD to " << n_attached
           << " sensitive volume(s)" << G4endl;
  }

private:
  G4String     fGdmlPath;
  G4GDMLParser fParser;
};

class PrimaryGeneratorAction : public G4VUserPrimaryGeneratorAction {
public:
  PrimaryGeneratorAction() : fGun(std::make_unique<G4ParticleGun>(1)) {}
  void GeneratePrimaries(G4Event* evt) override {
    fGun->GeneratePrimaryVertex(evt);
  }
private:
  std::unique_ptr<G4ParticleGun> fGun;
};

class RunAction : public G4UserRunAction {
public:
  explicit RunAction(G4String outPath) : fOutPath(std::move(outPath)) {}

  void BeginOfRunAction(const G4Run*) override {
    // Runtime RINDEX guard: if no material carries a RINDEX property,
    // G4OpticalPhysics produces zero Cherenkov photons silently.
    bool any_rindex = false;
    for (const auto* m : *G4Material::GetMaterialTable()) {
      const auto* mpt = m->GetMaterialPropertiesTable();
      if (mpt && mpt->GetProperty("RINDEX")) { any_rindex = true; break; }
    }
    if (!any_rindex)
      G4cerr << "[g4c] WARNING: no material has a RINDEX property — "
                "G4OpticalPhysics will produce ZERO photons. Add RINDEX "
                "to the radiator material (geant4-detector does this for "
                "optical specs)." << G4endl;

    gOut.file.reset(TFile::Open(fOutPath.c_str(), "RECREATE"));
    if (!gOut.file || gOut.file->IsZombie()) {
      G4cerr << "[g4c] FATAL: cannot open " << fOutPath << G4endl;
      std::exit(2);
    }
    gOut.tree = new TTree("Hits", "geant4_claude hits");
    gOut.tree->Branch("event",  &gOut.event_id, "event/I");
    gOut.tree->Branch("volume", gOut.volume,    "volume/C");
    gOut.tree->Branch("edep",   &gOut.edep,     "edep/D");
    gOut.tree->Branch("x",      &gOut.x,        "x/D");
    gOut.tree->Branch("y",      &gOut.y,        "y/D");
    gOut.tree->Branch("z",      &gOut.z,        "z/D");
    gOut.tree->Branch("t",      &gOut.t,        "t/D");
    gOut.tree->Branch("pdg",    &gOut.pdg,      "pdg/I");
  }

  void EndOfRunAction(const G4Run* run) override {
    if (gOut.file) {
      gOut.file->cd();
      if (gOut.tree) gOut.tree->Write();
      gOut.file->Close();
      gOut.file.reset();
      gOut.tree = nullptr;
    }
    G4cout << "[g4c] run ended: " << run->GetNumberOfEvent()
           << " events written to " << fOutPath << G4endl;
  }

private:
  G4String fOutPath;
};

class EventAction : public G4UserEventAction {
public:
  void BeginOfEventAction(const G4Event* evt) override {
    gBuf.clear();
    gBuf.event_id = evt->GetEventID();
  }
  void EndOfEventAction(const G4Event*) override {
    if (!gOut.tree) return;
    for (size_t i = 0; i < gBuf.edep.size(); ++i) {
      gOut.event_id = gBuf.event_id;
      const std::string& name = gBuf.volume[i];
      const size_t n = std::min<size_t>(name.size(), kVolumeNameMax - 1);
      std::memcpy(gOut.volume, name.data(), n);
      gOut.volume[n] = '\0';
      gOut.edep = gBuf.edep[i];
      gOut.x = gBuf.x[i]; gOut.y = gBuf.y[i];
      gOut.z = gBuf.z[i]; gOut.t = gBuf.t[i];
      gOut.pdg = gBuf.pdg[i];
      gOut.tree->Fill();
    }
  }
};

class ActionInitialization : public G4VUserActionInitialization {
public:
  explicit ActionInitialization(G4String outPath)
    : fOutPath(std::move(outPath)) {}
  void Build() const override {
    SetUserAction(new PrimaryGeneratorAction());
    SetUserAction(new RunAction(fOutPath));
    SetUserAction(new EventAction());
  }
private:
  G4String fOutPath;
};

}  // namespace g4c

int main(int argc, char** argv) {
  if (argc != 4) {
    std::cerr << "usage: " << argv[0]
              << " <geometry.gdml> <run.mac> <output.root>" << std::endl;
    return 1;
  }
  const std::string gdml = argv[1];
  const std::string mac  = argv[2];
  const std::string out  = argv[3];

  auto* runManager = G4RunManagerFactory::CreateRunManager(
                        G4RunManagerType::Serial);
  runManager->SetUserInitialization(new g4c::DetectorConstruction(gdml));

  auto* physics = new FTFP_BERT(0);
  physics->RegisterPhysics(new G4OpticalPhysics());
  runManager->SetUserInitialization(physics);

  runManager->SetUserInitialization(new g4c::ActionInitialization(out));

  G4UImanager::GetUIpointer()->ApplyCommand("/control/execute " + mac);

  delete runManager;
  return 0;
}
