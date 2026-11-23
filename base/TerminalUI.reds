module CorpoBiz

// Injects a "Biz" tab into any computer terminal standing near a
// registered business module's terminal position, turning it into that
// business's management interface. Generic over every module in
// CorpoBizRegistry.All() -- a second business's terminal, anywhere
// else in the world, gets this same tab automatically.
//
// The actual dashboard (backdrop, buttons, meters) is built by
// CorpoBizWebUI (WebUI.reds) as procedural ink widgets. This file
// handles terminal detection, tab injection, and clearing the vanilla
// Mail panel so the ink dashboard can fill it.
public class TerminalUI {

  public static func TerminalMatchRadius() -> Float {
    return 5.0;
  }

  public static func FindBiz(controller: ref<ComputerInkGameController>) -> ref<BizModule> {
    let ownerPos = controller.GetOwner().GetWorldPosition();
    let game = controller.GetOwner().GetGame();
    return CorpoBizRegistry.FindByPosition(game, ownerPos, TerminalUI.TerminalMatchRadius());
  }

  public static func MakeMenuButton(widgetName: String, displayName: String, iconID: CName) -> SComputerMenuButtonWidgetPackage {
    let pkg: SComputerMenuButtonWidgetPackage;
    pkg.widgetTweakDBID = t"DevicesUIDefinitions.MenuButtonWidget";
    pkg.libraryID = n"menuButton";
    pkg.libraryPath = r"base/gameplay/gui/world/computers/computer.inkwidget";
    pkg.widgetName = widgetName;
    pkg.displayName = displayName;
    pkg.iconID = iconID;
    pkg.isValid = true;
    return pkg;
  }
}

// Clears the vanilla Mail panel for a matched business terminal and
// renders the ink dashboard in its place. wrappedMethod runs first so
// the menu_mails canvas exists before CorpoBizWebUI looks for it.
@wrapMethod(ComputerInkGameController)
protected func InitializeMailsThumbnails(widgetsData: script_ref<array<SDocumentThumbnailWidgetPackage>>) -> Void {
  let mod = TerminalUI.FindBiz(this);
  if IsDefined(mod) {
    let empty: array<SDocumentThumbnailWidgetPackage>;
    widgetsData = empty;
  }
  wrappedMethod(widgetsData);
  if IsDefined(mod) {
    CorpoBizWebUI.Render(this, this.GetOwner().GetGame(), mod.Def());
  }
}

// Replaces the tab bar for a matched business terminal: Web, Network,
// and a "Biz" tab that reuses the vanilla Mail panel's plumbing
// (widgetName "mails") so GoToMenu's built-in dispatch shows/hides it.
@wrapMethod(ComputerInkGameController)
protected func InitializeMenuButtons(widgetsData: script_ref<array<SComputerMenuButtonWidgetPackage>>) -> Void {
  let mod = TerminalUI.FindBiz(this);
  if IsDefined(mod) {
    widgetsData = [
      TerminalUI.MakeMenuButton("internet", "Gameplay-Devices-Computers-Common-Internet", n"iconInternet"),
      TerminalUI.MakeMenuButton("devices", "Gameplay-Devices-Computers-Common-System", n"iconNetwork"),
      TerminalUI.MakeMenuButton("mails", "Biz", n"iconMail")
    ];
  }
  wrappedMethod(widgetsData);
}
