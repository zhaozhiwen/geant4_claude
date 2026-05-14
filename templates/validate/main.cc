// templates/validate/main.cc
//
// G4GDMLParser-based GDML validator. Called by `g4run validate-gdml`
// after xmllint passes. Catches the class of error xmllint cannot:
// undefined materials, missing volume references, bad solid refs,
// malformed auxiliary tags. Schema validation (Validate=true in the
// parser) is disabled because it requires fetching the GDML XSD over
// HTTP, which fails in sandboxed environments.
//
// Exit codes:
//   0  GDML parsed cleanly
//   1  parse failed (Geant4 error)
//   2  bad CLI

#include "G4GDMLParser.hh"
#include "G4LogicalVolumeStore.hh"
#include "G4StateManager.hh"
#include "G4VExceptionHandler.hh"
#include "G4VPhysicalVolume.hh"

#include <exception>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

// Geant4's default exception handler calls G4Abort() on fatal errors,
// which terminates the process via SIGABRT — useful in a running
// simulation, ugly for a validator (the user sees "core dumped" instead
// of a clean error line). This handler translates fatal G4Exceptions
// into std::runtime_error so main()'s try/catch returns a clean exit 1.
class ValidatorExceptionHandler : public G4VExceptionHandler {
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
    std::cerr << "[validate-gdml] warning at " << originOfException
              << " [" << exceptionCode << "]: " << description << std::endl;
    return false;
  }
};

}  // namespace

int main(int argc, char** argv) {
  if (argc != 2) {
    std::cerr << "usage: " << argv[0] << " <file.gdml>" << std::endl;
    return 2;
  }
  const std::string gdml = argv[1];

  G4StateManager::GetStateManager()->SetExceptionHandler(
      new ValidatorExceptionHandler);

  try {
    G4GDMLParser parser;
    parser.SetOverlapCheck(false);
    parser.Read(gdml, /* Validate = */ false);

    auto* world = parser.GetWorldVolume();
    if (!world) {
      std::cerr << "[validate-gdml] parser returned no world volume"
                << std::endl;
      return 1;
    }
    auto* lvs = G4LogicalVolumeStore::GetInstance();
    std::cout << "[validate-gdml] parsed " << lvs->size()
              << " logical volume(s); world = "
              << world->GetName() << std::endl;
    return 0;
  } catch (const std::exception& e) {
    std::cerr << "[validate-gdml] C++ exception: " << e.what() << std::endl;
    return 1;
  } catch (...) {
    std::cerr << "[validate-gdml] unknown C++ exception" << std::endl;
    return 1;
  }
}
