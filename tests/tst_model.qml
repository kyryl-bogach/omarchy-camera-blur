import QtQuick
import QtTest
import "../Model.js" as Model

TestCase {
  name: "CameraBlurModel"

  function test_parseBlurState() {
    compare(Model.parseBlurState("[video]\nbackground_removal = true\n"), true)
    compare(Model.parseBlurState("[video]\nbackground_removal=false # disabled\n"), false)
    compare(Model.parseBlurState("[audio]\nbackground_removal = true\n"), null)
    compare(Model.parseBlurState("[video]\nother = true\n"), null)
  }

  function test_parseBlurStateUsesVideoSectionOnly() {
    var config = "background_removal = false\n"
      + "[audio]\nbackground_removal = false\n"
      + "[video]\nbackground_removal = true\n"
      + "[other]\nbackground_removal = false\n"

    compare(Model.parseBlurState(config), true)
  }

  function test_applyResults() {
    var state = {
      installed: false,
      installChecked: false,
      running: true,
      virtualCameraPresent: false,
      streaming: false,
      blurKnown: false,
      blurEnabled: false
    }

    Model.applyInstalledResult(state, 0)
    compare(state.installed, true)
    compare(state.installChecked, true)

    Model.applyRunningResult(state, 1)
    compare(state.running, false)

    Model.applyVirtualCameraResult(state, 0)
    compare(state.virtualCameraPresent, true)

    Model.applyStreamingResult(state, 0)
    compare(state.streaming, true)

    compare(Model.applyConfig(state, "[video]\nbackground_removal = true\n"), true)
    compare(state.blurKnown, true)
    compare(state.blurEnabled, true)
  }
}
