Khajiit Feng Shui is a comprehensive UI customization addon for The Elder Scrolls Online that allows you to move, scale, and customize nearly every element of your console UI. Built with LibCombatAlerts integration, this addon provides an intuitive interface for rearranging your HUD to match your preferred layout.

**KEY FEATURES:**

**UI Element Management:**
- Move and scale over 40 different UI elements including:
  - Player attribute bars (Health, Magicka, Stamina, Werewolf, Mount, Siege)
  - Compass and quest tracker
  - Action bar and synergy prompts
  - Target frame and reticle
  - Buff and debuff displays (player and target)
  - Group frames (small and raid layouts)
  - Chat windows, subtitles, and alerts
  - Equipment status, infamy, Tel Var, and Volendrung meters
  - Battleground score, endless dungeon tracker, and more

**Edit Mode:**
- Enter edit mode using `/kfsedit` or the gamepad shortcut (Y/Triangle button)
- Gamepad-friendly navigation with right stick movement
- Cycle through panels using shoulder buttons (LB/RB) or D-pad
- Toggle label visibility with `/kfslabels` or the quaternary button
- Visual grid overlay for precise alignment (when enabled)
- Individual panel controls via settings menu

**Grid Snapping:**
- Optional grid snapping system for precise alignment
- Adjustable grid size (2-128 pixels)
- Snap to grid when movement ends
- Visual grid overlay in edit mode

**Pyramid Layout:**
- Automatic pyramid arrangement for Health, Magicka, and Stamina bars
- Health bar centered on top
- Magicka and Stamina bars side-by-side below
- Adjustable offset to fine-tune the entire layout
- Move the entire pyramid by dragging any of the three bars in edit mode

**Scaling System:**
- Scale any UI element from 50% to 150% in 5% increments
- Special handling for attribute bars that preserves shrink/expand behavior
- Option to keep attribute bars always expanded (even at full resources)
- Proper scaling for group frames and complex UI elements

**Profile Management:**
- Choose between account-wide or per-character layouts
- Switch profiles anytime (requires UI reload)
- Perfect for different characters with different UI preferences

**Additional Options:**
- Toggle buff/debuff cooldown animations
- Enable/disable global cooldown indicator on action bar
- Show/hide boss health bar on compass
- Show/hide reticle (crosshair)
- Individual enable/disable toggles for each panel

**HOW TO USE:**

**Basic Movement (Settings Menu):**
1. Open Add-On Settings → Khajiit Feng Shui
2. Navigate to "Individual Controls" section
3. Find the UI element you want to move
4. Click "Move" button
5. Drag the element to desired position
6. Click "Move" again or press Escape to finish

**Edit Mode (Recommended):**
1. Type `/kfsedit` in chat or use gamepad shortcut
2. Use right stick (gamepad) or mouse to move the highlighted panel
3. Use LB/RB or D-pad to cycle between panels
4. Adjust scale using the slider in settings
5. Type `/kfsedit` again or press B/Circle to exit

**Settings Access:**
- Add-On Settings → Khajiit Feng Shui
- All panels are listed under "Individual Controls"
- Each panel has: Enable toggle, Scale slider, and Move button
- Global options at the top (grid, profile mode, etc.)

**FAQ & TROUBLESHOOTING:**

**Q: Why can't I move a specific UI element?**
A: Make sure the "Enable Mover" checkbox is checked for that panel in settings. Some elements may be disabled by default or require the panel to be visible in-game.

**Q: My changes aren't saving.**
A: Check your "Layout Scope" setting. If set to "Per Character", each character has separate layouts. Also ensure you're not in edit mode when trying to save (exit with `/kfsedit`).

**Q: The pyramid layout isn't working.**
A: Ensure all three attribute bars (Health, Magicka, Stamina) have their movers enabled. The pyramid layout requires all three bars to be active.

**Q: Can I use this with other UI addons?**
A: Yes, but be aware that other addons that modify the same UI elements may conflict. Disable the mover for specific panels if you want another addon to control them.

**Q: How do I reset everything?**
A: Use the "Reset Positions" button in settings. This will reset all positions and scales to default and reload the UI.

**Q: Why does my UI reload when changing some settings?**
A: Some settings (buff animations, boss bar, reticle, always expanded bars, profile mode) require a UI reload to properly apply hooks and changes.

**Q: The grid overlay isn't showing.**
A: Enable "Enable Grid Snap" in settings and enter edit mode. The grid only appears when moving panels.

**Q: Can I move panels with keyboard/mouse?**
A: Yes! While edit mode is optimized for gamepad, you can use the "Move" button in settings for keyboard/mouse control, or use edit mode with mouse movement.

**REQUIREMENTS:**
- LibCombatAlerts (for mover functionality)
- LibHarvensAddonSettings (for settings menu)

**COMPATIBILITY:**
Works with both keyboard/mouse and gamepad interfaces. Optimized for console UI but works on PC as well. 

**NOTES:**
- Some UI elements may require specific game states to be visible (e.g., group frames require being in a group)
- Attribute bar scaling intelligently handles the game's shrink/expand mechanics
- Custom control wrappers are used for some elements to ensure proper positioning
- All positions and scales are saved per profile (account or character)

Enjoy customizing your UI to achieve the perfect Khajiit-approved feng shui balance!
