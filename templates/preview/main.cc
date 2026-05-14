// templates/preview/main.cc
//
// Headless GDML preview using Geant4's RayTracer visualization driver.
// RayTracer does pure CPU ray tracing — no OpenGL, X11, EGL, or
// framebuffer needed, so it works inside any container.
//
// Usage: preview_gdml <geometry.gdml> <out_dir>
//
// Writes three JPEGs to out_dir/:
//   preview_iso.jpg  — 30°/60° isometric
//   preview_xy.jpg   — looking down +z (top-down)
//   preview_yz.jpg   — looking down +x (side)
//
// Each image is 800×600. Background is white; geometry is drawn surface
// style. The world volume is included automatically.

#include "G4RunManagerFactory.hh"
#include "G4UImanager.hh"
#include "G4VUserDetectorConstruction.hh"
#include "G4StateManager.hh"
#include "G4VExceptionHandler.hh"
#include "G4GDMLParser.hh"
#include "FTFP_BERT.hh"
#include "G4VisExecutive.hh"

#include <exception>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

class PreviewExceptionHandler : public G4VExceptionHandler {
 public:
  G4bool Notify(const char* originOfException,
                const char* exceptionCode,
                G4ExceptionSeverity severity,
                const char* description) override {
    if (severity == FatalException ||
        severity == FatalErrorInArgument ||
        severity == RunMustBeAborted ||
        severity == EventMustBeAborted) {
      throw std::runtime_error(std::string(originOfException) + ": [" +
                               exceptionCode + "] " + description);
    }
    std::cerr << "[preview] warning at " << originOfException
              << " [" << exceptionCode << "]: " << description << std::endl;
    return false;
  }
};

class GdmlGeometry : public G4VUserDetectorConstruction {
 public:
  explicit GdmlGeometry(std::string path) : path_(std::move(path)) {}
  G4VPhysicalVolume* Construct() override {
    G4GDMLParser parser;
    parser.SetOverlapCheck(false);
    parser.Read(path_, false);
    return parser.GetWorldVolume();
  }

 private:
  std::string path_;
};

void cmd_q(G4UImanager* ui, const std::string& s) {
  ui->ApplyCommand(s);
}

}  // namespace

int main(int argc, char** argv) {
  if (argc != 3) {
    std::cerr << "usage: " << argv[0]
              << " <geometry.gdml> <out_dir>" << std::endl;
    return 2;
  }
  const std::string gdml = argv[1];
  const std::string out  = argv[2];

  G4StateManager::GetStateManager()->SetExceptionHandler(
      new PreviewExceptionHandler);

  try {
    auto* rm = G4RunManagerFactory::CreateRunManager(
        G4RunManagerType::Serial);
    rm->SetUserInitialization(new GdmlGeometry(gdml));
    rm->SetUserInitialization(new FTFP_BERT(0));
    rm->Initialize();

    auto* vis = new G4VisExecutive("Quiet");
    vis->Initialize();

    auto* ui = G4UImanager::GetUIpointer();
    // Minimal sequence — works around the "No valid current viewer"
    // quirk seen in Geant4 11.4 when /vis/rayTracer commands are issued
    // through ApplyCommand before /vis/scene/create has been called.
    // Order: explicit scene → viewer → draw → viewpoint → trace.
    cmd_q(ui, "/vis/scene/create");
    cmd_q(ui, "/vis/sceneHandler/create RayTracer");
    cmd_q(ui, "/vis/viewer/create");
    cmd_q(ui, "/vis/viewer/set/background 1 1 1");
    cmd_q(ui, "/vis/scene/add/volume");
    cmd_q(ui, "/vis/sceneHandler/attach");

    const std::string out_iso = out + "/preview_iso.jpg";
    const std::string out_xy  = out + "/preview_xy.jpg";
    const std::string out_yz  = out + "/preview_yz.jpg";

    cmd_q(ui, "/vis/viewer/set/viewpointThetaPhi 30 60 deg");
    cmd_q(ui, "/vis/rayTracer/trace " + out_iso);

    cmd_q(ui, "/vis/viewer/set/viewpointThetaPhi 90 0 deg");
    cmd_q(ui, "/vis/rayTracer/trace " + out_xy);

    cmd_q(ui, "/vis/viewer/set/viewpointThetaPhi 0 90 deg");
    cmd_q(ui, "/vis/rayTracer/trace " + out_yz);

    std::cout << "[preview] wrote:\n  " << out_iso
              << "\n  " << out_xy
              << "\n  " << out_yz << std::endl;

    delete rm;
    return 0;
  } catch (const std::exception& e) {
    std::cerr << "[preview] error: " << e.what() << std::endl;
    return 1;
  }
}
