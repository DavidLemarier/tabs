fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()

describe 'MRU List', ->
  workspaceElement = null

  beforeEach ->
    workspaceElement = soldat.workspace.getElement()

    waitsForPromise ->
      soldat.workspace.open('sample.js')

    waitsForPromise ->
      soldat.packages.activatePackage("tabs")

  describe ".activate()", ->
    initialPaneCount = soldat.workspace.getPanes().length

    it "has exactly one modal panel per pane", ->
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe initialPaneCount

      pane = soldat.workspace.getActivePane()
      pane.splitRight()
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe initialPaneCount + 1

      pane = soldat.workspace.getActivePane()
      pane.splitDown()
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe initialPaneCount + 2

      waitsForPromise ->
        pane = soldat.workspace.getActivePane()
        Promise.resolve(pane.close())

      runs ->
        expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe initialPaneCount + 1

      waitsForPromise ->
        pane = soldat.workspace.getActivePane()
        Promise.resolve(pane.close())

      runs ->
        expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe initialPaneCount

    it "Doesn't build list until activated for the first time", ->
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe initialPaneCount
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher li').length).toBe 0

    it "Doesn't activate when a single pane item is open", ->
      pane = soldat.workspace.getActivePane()
      soldat.commands.dispatch(pane, 'pane:show-next-recently-used-item')
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher li').length).toBe 0

  describe "contents", ->
    pane = null

    beforeEach ->
      waitsForPromise ->
        soldat.workspace.open("sample.png")
      pane = soldat.workspace.getActivePane()

    it "has one item per tab", ->
      if pane.onChooseNextMRUItem?
        expect(pane.getItems().length).toBe 2
        soldat.commands.dispatch(workspaceElement, 'pane:show-next-recently-used-item')
        expect(workspaceElement.querySelectorAll('.tabs-mru-switcher li').length).toBe 2

    it "switches between two items", ->
      firstActiveItem = pane.getActiveItem()
      soldat.commands.dispatch(workspaceElement, 'pane:show-next-recently-used-item')
      secondActiveItem = pane.getActiveItem()
      expect(secondActiveItem).toNotBe(firstActiveItem)
      soldat.commands.dispatch(workspaceElement, 'pane:move-active-item-to-top-of-stack')
      thirdActiveItem = pane.getActiveItem()
      expect(thirdActiveItem).toBe(secondActiveItem)
      soldat.commands.dispatch(workspaceElement, 'pane:show-next-recently-used-item')
      soldat.commands.dispatch(workspaceElement, 'pane:move-active-item-to-top-of-stack')
      fourthActiveItem = pane.getActiveItem()
      expect(fourthActiveItem).toBe(firstActiveItem)

  describe "config", ->
    configKey = 'tabs.enableMruTabSwitching'
    dotSoldatPath = null

    beforeEach ->
      dotSoldatPath = temp.path('tabs-spec-mru-config')
      soldat.config.configDirPath = dotSoldatPath
      soldat.config.configFilePath = path.join(soldat.config.configDirPath, "soldat.config.cson")
      soldat.keymaps.configDirPath = dotSoldatPath

    afterEach ->
      fs.removeSync(dotSoldatPath)

    it "defaults on", ->
      expect(soldat.config.get(configKey)).toBe(true)

      bindings = soldat.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-tab')
      expect(bindings.length).toBe(1)
      expect(bindings[0].command).toBe('pane:show-next-recently-used-item')

      bindings = soldat.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-tab ^ctrl')
      expect(bindings.length).toBe(1)
      expect(bindings[0].command).toBe('pane:move-active-item-to-top-of-stack')

      bindings = soldat.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-shift-tab')
      expect(bindings.length).toBe(1)
      expect(bindings[0].command).toBe('pane:show-previous-recently-used-item')

      bindings = soldat.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-shift-tab ^ctrl')
      expect(bindings.length).toBe(1)
      expect(bindings[0].command).toBe('pane:move-active-item-to-top-of-stack')

    it "alters keybindings when disabled", ->
      soldat.config.set(configKey, false)
      bindings = soldat.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-tab')
      expect(bindings.length).toBe(2)
      expect(bindings[0].command).toBe('pane:show-next-item')

      bindings = soldat.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-tab ^ctrl')
      expect(bindings.length).toBe(2)
      expect(bindings[0].command).toBe('unset!')

      bindings = soldat.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-shift-tab')
      expect(bindings.length).toBe(2)
      expect(bindings[0].command).toBe('pane:show-previous-item')

      bindings = soldat.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-shift-tab ^ctrl')
      expect(bindings.length).toBe(2)
      expect(bindings[0].command).toBe('unset!')
