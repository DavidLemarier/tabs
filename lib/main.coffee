{CompositeDisposable, Disposable} = require 'soldat'
FileIcons = require './file-icons'
layout = require './layout'
TabBarView = require './tab-bar-view'
MRUListView = require './mru-list-view'
_ = require 'underscore-plus'

module.exports =
  activate: (state) ->
    @subscriptions = new CompositeDisposable()
    layout.activate()
    @tabBarViews = []
    @mruListViews = []

    keyBindSource = 'tabs package'
    configKey = 'tabs.enableMruTabSwitching'

    @updateTraversalKeybinds = ->
      # We don't modify keybindings based on our setting if the user has already tweaked them.
      bindings = soldat.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-tab')
      return if bindings.length > 1 and bindings[0].source isnt keyBindSource
      bindings = soldat.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-shift-tab')
      return if bindings.length > 1 and bindings[0].source isnt keyBindSource

      if soldat.config.get(configKey)
        soldat.keymaps.removeBindingsFromSource(keyBindSource)
      else
        disabledBindings =
          'body':
            'ctrl-tab': 'pane:show-next-item'
            'ctrl-tab ^ctrl': 'unset!'
            'ctrl-shift-tab': 'pane:show-previous-item'
            'ctrl-shift-tab ^ctrl': 'unset!'
        soldat.keymaps.add(keyBindSource, disabledBindings, 0)

    @subscriptions.add soldat.config.observe configKey, => @updateTraversalKeybinds()
    @subscriptions.add soldat.keymaps.onDidLoadUserKeymap? => @updateTraversalKeybinds()

    # If the command bubbles up without being handled by a particular pane,
    # close all tabs in all panes
    @subscriptions.add soldat.commands.add 'soldat-workspace',
      'tabs:close-all-tabs': =>
        # We loop backwards because the panes are
        # removed from the array as we go
        for tabBarView in @tabBarViews by -1
          tabBarView.closeAllTabs()

    paneContainers =
      center: soldat.workspace.getCenter?() ? soldat.workspace
      left: soldat.workspace.getLeftDock?()
      right: soldat.workspace.getRightDock?()
      bottom: soldat.workspace.getBottomDock?()

    Object.keys(paneContainers).forEach (location) =>
      container = paneContainers[location]
      return unless container
      @subscriptions.add container.observePanes (pane) =>
        tabBarView = new TabBarView(pane, location)
        mruListView = new MRUListView
        mruListView.initialize(pane)

        paneElement = pane.getElement()
        paneElement.insertBefore(tabBarView.element, paneElement.firstChild)

        @tabBarViews.push(tabBarView)
        pane.onDidDestroy => _.remove(@tabBarViews, tabBarView)
        @mruListViews.push(mruListView)
        pane.onDidDestroy => _.remove(@mruListViews, mruListView)

  deactivate: ->
    layout.deactivate()
    @subscriptions.dispose()
    @fileIconsDisposable?.dispose()
    tabBarView.destroy() for tabBarView in @tabBarViews
    mruListView.destroy() for mruListView in @mruListViews
    return

  consumeFileIcons: (service) ->
    FileIcons.setService(service)
    @updateFileIcons()
    new Disposable =>
      FileIcons.resetService()
      @updateFileIcons()

  updateFileIcons: ->
    for tabBarView in @tabBarViews
      tabView.updateIcon() for tabView in tabBarView.getTabs()
