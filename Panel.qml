import QtQuick
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.kyryl-bogach.camera-blur"
  ipcTarget: "io.github.kyryl-bogach.camera-blur"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool installed: false
  property bool installChecked: false
  property bool running: false
  property bool virtualCameraPresent: false
  property bool streaming: false
  property bool blurEnabled: false
  property bool blurKnown: false
  property bool togglePending: false
  property bool hotkeysHint: false
  property bool toggleBaseline: false
  property bool toggleBaselineKnown: false
  property string lastError: ""

  readonly property var barIdentity: hostWidget || root
  readonly property string configPath: Quickshell.env("HOME") + "/.config/nvbroadcast/config.toml"
  readonly property color contentForeground: root.bar ? root.bar.foreground : Color.foreground
  readonly property string contentFontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  function open() {
    root.refresh()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refreshConfig() {
    configFile.reload()
  }

  function refreshStatus() {
    Model.checkInstalled(installedProc)
    Model.checkRunning(runningProc)
    Model.checkVirtualCamera(vcamProc)
    Model.checkStreaming(streamProc)
    root.refreshConfig()
  }

  function refresh() {
    root.refreshStatus()
  }

  function toggleBlur() {
    if (!root.running) {
      root.open()
      return
    }
    if (toggleProc.running) return
    root.toggleBaseline = root.blurEnabled
    root.toggleBaselineKnown = root.blurKnown
    root.togglePending = true
    root.hotkeysHint = false
    root.lastError = ""
    if (!Model.toggleBlur(toggleProc)) root.togglePending = false
  }

  function startOrStop() {
    root.lastError = ""
    if (root.running) Model.stop(controlProc)
    else Model.start(controlProc)
  }

  function openApplication() {
    root.lastError = ""
    Model.open(openProc)
  }

  Component.onCompleted: root.refreshStatus()

  Timer {
    interval: 5000
    repeat: true
    running: true
    onTriggered: root.refreshStatus()
  }

  Timer {
    id: actionRefreshTimer
    interval: 700
    repeat: false
    onTriggered: root.refreshStatus()
  }

  Timer {
    id: toggleCheckTimer
    interval: 1200
    repeat: false
    onTriggered: {
      root.refreshConfig()
      toggleResultTimer.restart()
    }
  }

  Timer {
    id: toggleResultTimer
    interval: 160
    repeat: false
    onTriggered: {
      if (!root.togglePending) return
      root.hotkeysHint = root.running && root.toggleBaselineKnown && root.blurKnown
        && root.blurEnabled === root.toggleBaseline
      root.togglePending = false
    }
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      var before = root.blurEnabled
      var parsed = Model.applyConfig(root, text())
      if (root.togglePending && parsed !== null && root.blurEnabled !== root.toggleBaseline) {
        root.togglePending = false
        root.hotkeysHint = false
        toggleCheckTimer.stop()
        toggleResultTimer.stop()
      } else if (!root.togglePending && before !== root.blurEnabled) {
        root.hotkeysHint = false
      }
    }
    onLoadFailed: {
      root.blurKnown = false
      root.blurEnabled = false
    }
    onFileChanged: reload()
  }

  Process {
    id: installedProc
    onExited: function(exitCode) {
      Model.applyInstalledResult(root, exitCode)
    }
  }

  Process {
    id: runningProc
    onExited: function(exitCode) {
      Model.applyRunningResult(root, exitCode)
    }
  }

  Process {
    id: vcamProc
    onExited: function(exitCode) {
      Model.applyVirtualCameraResult(root, exitCode)
    }
  }

  Process {
    id: streamProc
    onExited: function(exitCode) {
      Model.applyStreamingResult(root, exitCode)
    }
  }

  Process {
    id: toggleProc
    stderr: StdioCollector { id: toggleError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = String(toggleError.text || "").trim()
          || "NV Broadcast rejected the blur toggle."
      }
      toggleCheckTimer.restart()
    }
  }

  Process {
    id: controlProc
    stderr: StdioCollector { id: controlError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = String(controlError.text || "").trim()
          || "Could not change the NV Broadcast process state."
      }
      actionRefreshTimer.restart()
    }
  }

  Process {
    id: openProc
    stderr: StdioCollector { id: openError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = String(openError.text || "").trim()
          || "Could not open NV Broadcast."
      }
      actionRefreshTimer.restart()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    readonly property real bodySpacing: Style.space(10)
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: contentColumn
        width: parent.width
        spacing: panel.bodySpacing

        BorderSurface {
          id: previewSurface
          width: parent.width
          implicitHeight: width * 9 / 16
          radius: Style.cornerRadius
          clip: true
          color: Qt.rgba(root.contentForeground.r * 0.08, root.contentForeground.g * 0.08,
                         root.contentForeground.b * 0.08, 1)
          borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)

          Loader {
            id: previewLoader
            anchors.fill: parent
            active: root.opened && root.running && root.virtualCameraPresent && root.streaming
            sourceComponent: previewComponent
          }

          Text {
            anchors.centerIn: parent
            width: parent.width - Style.space(40)
            visible: !root.running
            text: "Start NV Broadcast to see the processed preview."
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          Text {
            anchors.centerIn: parent
            width: parent.width - Style.space(40)
            visible: root.running && !root.virtualCameraPresent
            text: "The virtual camera /dev/video10 is missing."
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          Text {
            anchors.centerIn: parent
            width: parent.width - Style.space(40)
            visible: root.running && root.virtualCameraPresent && !root.streaming
            text: "NV Broadcast is not streaming. Open NV Broadcast and start the broadcast."
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }
        }

        Item {
          width: parent.width
          implicitHeight: Math.max(titleIcon.implicitHeight, titleLabels.implicitHeight, refreshButton.implicitHeight)

          Text {
            id: titleIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰄀"
            color: root.blurEnabled && root.running ? Color.accent : root.contentForeground
            opacity: root.running ? 1.0 : 0.42
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.display
            textFormat: Text.PlainText
          }

          Column {
            id: titleLabels
            anchors.left: titleIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: refreshButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Text {
              width: parent.width
              text: "Camera Blur"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }

            Text {
              width: parent.width
              text: !root.installChecked ? "CHECKING NV BROADCAST"
                : (!root.installed ? "NV BROADCAST NOT INSTALLED"
                : (root.running ? "NV BROADCAST RUNNING" : "NV BROADCAST STOPPED"))
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.8
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }
          }

          PanelActionButton {
            id: refreshButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰑐"
            tooltipText: "Refresh status"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            focusable: true
            onClicked: root.refresh()
          }
        }

        Column {
          visible: root.installChecked && root.installed
          width: parent.width
          spacing: Style.space(7)

          PanelSeparator { width: parent.width; foreground: root.contentForeground }
          StatusRow { label: "NV Broadcast running"; value: root.running ? "Yes" : "No" }
          StatusRow { label: "Virtual camera /dev/video10"; value: root.virtualCameraPresent ? "Present" : "Missing" }
          StatusRow { label: "Broadcast streaming"; value: root.streaming ? "Yes" : "No" }
          StatusRow { label: "Background blur"; value: root.blurKnown ? (root.blurEnabled ? "On" : "Off") : "Unknown" }

          Text {
            visible: root.hotkeysHint
            width: parent.width
            text: "The remote toggle did not respond. See the Remote Toggle Setup section in the plugin README."
            color: root.bar ? root.bar.urgent : Color.urgent
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          Text {
            visible: root.lastError !== ""
            width: parent.width
            text: root.lastError
            color: root.bar ? root.bar.urgent : Color.urgent
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          Button {
            width: parent.width
            text: root.togglePending ? "Checking Blur State..." : "Toggle Blur"
            bordered: true
            focusable: true
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            enabled: root.running && !root.togglePending
            onClicked: root.toggleBlur()
          }

          Row {
            width: parent.width
            spacing: Style.space(7)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: root.running ? "Stop NV Broadcast" : "Start NV Broadcast"
              bordered: true
              focusable: true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.startOrStop()
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Open NV Broadcast"
              bordered: true
              focusable: true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.openApplication()
            }
          }
        }

        Column {
          visible: root.installChecked && !root.installed
          width: parent.width
          spacing: Style.space(7)

          PanelSeparator { width: parent.width; foreground: root.contentForeground }

          Text {
            width: parent.width
            text: "Install NV Broadcast, configure the virtual camera, then enable Global Hotkeys once in NV Broadcast settings."
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          Text {
            width: parent.width
            text: "git clone https://github.com/Hkshoonya/nvidia-broadcast-linux.git\n"
              + "cd nvidia-broadcast-linux\n"
              + "./install.sh --runtime cuda\n\n"
              + "See the plugin README for the remote-toggle setup."
            color: root.contentForeground
            font.family: "monospace"
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WrapAnywhere
            textFormat: Text.PlainText
          }
        }
      }
    }
  }

  Component {
    id: previewComponent
    Item {
      id: previewHost
      property string cameraError: ""
      readonly property var matchedDevice: {
        var inputs = mediaDevices.videoInputs
        for (var i = 0; i < inputs.length; i++) {
          if (String(inputs[i].id) === Model.virtualCamera) return inputs[i]
        }
        return null
      }

      function syncCamera() {
        if (previewHost.matchedDevice === null) {
          camera.active = false
          return
        }

        camera.cameraDevice = previewHost.matchedDevice
        camera.active = root.opened
      }

      onMatchedDeviceChanged: syncCamera()

      MediaDevices { id: mediaDevices }
      Camera {
        id: camera
        Component.onCompleted: previewHost.syncCamera()
        onErrorOccurred: function(error, errorString) {
          previewHost.cameraError = errorString
        }
      }
      CaptureSession { camera: camera; videoOutput: videoOutput }
      VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
      }
      Rectangle {
        anchors.fill: parent
        visible: previewHost.matchedDevice === null || camera.error !== Camera.NoError
        color: Qt.rgba(0, 0, 0, 0.72)
        Text {
          anchors.centerIn: parent
          width: parent.width - Style.space(40)
          text: previewHost.matchedDevice === null
            ? "Preview unavailable for /dev/video10. If you installed the virtual camera after login, restart the Omarchy shell once."
            : (previewHost.cameraError || camera.errorString || "The virtual camera is unavailable.")
          color: "white"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
        }
      }
    }
  }

  component StatusRow: Item {
    required property string label
    required property string value
    width: parent ? parent.width : 0
    implicitHeight: Math.max(statusLabel.implicitHeight, statusValue.implicitHeight)

    Text {
      id: statusLabel
      anchors.left: parent.left
      anchors.right: statusValue.left
      text: parent.label
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }

    Text {
      id: statusValue
      anchors.right: parent.right
      text: parent.value
      color: Qt.darker(root.contentForeground, 1.35)
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      textFormat: Text.PlainText
    }
  }
}
