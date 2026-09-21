.pragma library

var applicationId = "com.doczeus.NVBroadcast"
var virtualCamera = "/dev/video10"

function parseBlurState(raw) {
  var lines = String(raw || "").split("\n")
  var inVideo = false

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/^\s+|\s+$/g, "")
    if (line === "" || line.charAt(0) === "#") continue

    var section = line.match(/^\[([^\]]+)\]$/)
    if (section) {
      inVideo = section[1].replace(/^\s+|\s+$/g, "") === "video"
      continue
    }

    if (!inVideo) continue
    var setting = line.match(/^background_removal\s*=\s*(true|false)\s*(?:#.*)?$/i)
    if (setting) return setting[1].toLowerCase() === "true"
  }

  return null
}

function run(process, command) {
  if (!process || process.running) return false
  process.command = command
  process.running = true
  return true
}

function checkInstalled(process) {
  return run(process, ["bash", "-lc", "command -v nvbroadcast >/dev/null 2>&1"])
}

function checkRunning(process) {
  return run(process, [
    "bash", "-lc",
    "gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.NameHasOwner " + applicationId + " 2>/dev/null | grep -q true"
  ])
}

function checkVirtualCamera(process) {
  return run(process, ["test", "-e", virtualCamera])
}

function checkStreaming(process) {
  return run(process, ["v4l2-ctl", "-d", virtualCamera, "--get-fmt-video"])
}

function toggleBlur(process) {
  return run(process, ["gapplication", "action", applicationId, "toggle-background"])
}

function start(process) {
  return run(process, [
    "bash", "-lc", "nohup nvbroadcast >/dev/null 2>&1 </dev/null &"
  ])
}

function stop(process) {
  return run(process, [
    "bash", "-lc",
    "pkill -x nvbroadcast 2>/dev/null; pkill -f 'python -m nvbroadcas[t]' 2>/dev/null; true"
  ])
}

function open(process) {
  return start(process)
}

function applyInstalledResult(state, exitCode) {
  state.installed = exitCode === 0
  state.installChecked = true
  if (!state.installed) state.running = false
}

function applyRunningResult(state, exitCode) {
  state.running = exitCode === 0
}

function applyVirtualCameraResult(state, exitCode) {
  state.virtualCameraPresent = exitCode === 0
}

function applyStreamingResult(state, exitCode) {
  state.streaming = exitCode === 0
}

function applyConfig(state, raw) {
  var parsed = parseBlurState(raw)
  state.blurKnown = parsed !== null
  state.blurEnabled = parsed === true
  return parsed
}
