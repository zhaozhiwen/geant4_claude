// geant4_claude_main.cc
//
// Generic Geant4 main for the geant4_claude plugin:
//   - loads any GDML geometry,
//   - attaches a generic sensitive detector to every logical volume tagged
//     <auxiliary auxtype="sensitive" auxvalue="true"/>,
//     <auxiliary auxtype="sensitive" auxvalue="1"/>,
//   - runs a user-provided macro (FTFP_BERT physics list),
//   - writes one flat TTree "Hits" with branches:
//       event/I, volume/C, edep/D, x/D, y/D, z/D, t/D, pdg/I.
//
// Usage:  geant4_claude_main <geometry.gdml> <run.mac> <output.root>
//
// Sequential mode only. MT and a thread-safe TTree filler can come later.

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
#include "G4VPhysicalVolume.hh"
#include "G4SDManager.hh"
#include "G4VSensitiveDetector.hh"
#include "G4Step.hh"
#include "G4Track.hh"
#include "G4SystemOfUnits.hh"
#include "G4GDMLParser.hh"
#include "FTFP_BERT.hh"

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

// ---- shared per-event buffer (sequential mode) -----------------------------
struct EventBuffer {
  int                       event_id = -1;
  std::vector<std::string>  volume;
  std::vector<double>       edep;
  std::vector<double>       x, y, z, t;
  std::vector<int>          pdg;

  void clear() {
    volume.clear();
    edep.clear();
    x.clear(); y.clear(); z.clear(); t.clear();
    pdg.clear();
  }
};
static EventBuffer gBuf;

constexpr int kVolumeNameMax = 64;

// ---- output state (one TTree per run) --------------------------------------
struct OutputState {
  std::unique_ptr<TFile> file;
  TTree*                 tree = nullptr;
  // staging row
  Int_t    event_id = 0;
  Int_t    pdg = 0;
  Double_t edep = 0., x = 0., y = 0., z = 0., t = 0.;
  char     volume[kVolumeNameMax] = {0};
};
static OutputState gOut;

// ---- generic sensitive detector --------------------------------------------
class GenericSD : public G4VSensitiveDetector {
public:
  explicit GenericSD(const G4String& name) : G4VSensitiveDetector(name) {}

  G4bool ProcessHits(G4Step* step, G4TouchableHistory*) override {
    const G4double edep = step->GetTotalEnergyDeposit();
    if (edep <= 0.) return false;

    const auto& pos    = step->GetPreStepPoint()->GetPosition();
    const auto  time   = step->GetPreStepPoint()->GetGlobalTime();
    const auto* track  = step->GetTrack();
    const auto* lv     = step->GetPreStepPoint()
                            ->GetTouchableHandle()
                            ->GetVolume()
                            ->GetLogicalVolume();

    gBuf.volume.push_back(lv->GetName());
    gBuf.edep.push_back(edep / MeV);
    gBuf.x.push_back(pos.x() / mm);
    gBuf.y.push_back(pos.y() / mm);
    gBuf.z.push_back(pos.z() / mm);
    gBuf.t.push_back(time / ns);
    gBuf.pdg.push_back(track->GetDefinition()->GetPDGEncoding());
    return true;
  }
};

// ---- detector construction: GDML + auto-SD ---------------------------------
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
      for (const auto& a : aux) {
        if (a.type == "sensitive" && (a.value == "true" || a.value == "1")) {
          sensitive = true;
          break;
        }
      }
      if (!sensitive) continue;

      auto* sd = new GenericSD("SD/" + lv->GetName());
      sdm->AddNewDetector(sd);
      lv->SetSensitiveDetector(sd);
      ++n_attached;
    }
    G4cout << "[g4c] attached SD to " << n_attached
           << " sensitive volume(s)" << G4endl;
  }

private:
  G4String     fGdmlPath;
  G4GDMLParser fParser;
};

// ---- particle gun ----------------------------------------------------------
class PrimaryGeneratorAction : public G4VUserPrimaryGeneratorAction {
public:
  PrimaryGeneratorAction() : fGun(std::make_unique<G4ParticleGun>(1)) {}
  void GeneratePrimaries(G4Event* evt) override {
    fGun->GeneratePrimaryVertex(evt);
  }
private:
  std::unique_ptr<G4ParticleGun> fGun;
};

// ---- run / event actions ---------------------------------------------------
class RunAction : public G4UserRunAction {
public:
  explicit RunAction(G4String outPath) : fOutPath(std::move(outPath)) {}

  void BeginOfRunAction(const G4Run*) override {
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
      gOut.x    = gBuf.x[i];
      gOut.y    = gBuf.y[i];
      gOut.z    = gBuf.z[i];
      gOut.t    = gBuf.t[i];
      gOut.pdg  = gBuf.pdg[i];
      gOut.tree->Fill();
    }
  }
};

// ---- action init -----------------------------------------------------------
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
  runManager->SetUserInitialization(new FTFP_BERT(0));
  runManager->SetUserInitialization(new g4c::ActionInitialization(out));

  G4UImanager::GetUIpointer()->ApplyCommand("/control/execute " + mac);

  delete runManager;
  return 0;
}
