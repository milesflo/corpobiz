module CorpoBiz

// Renders a real, fully interactive visual dashboard (backdrop panel,
// header, stock meter, cash tile, per-role cards) for a business's
// terminal as actual ink widgets (inkCanvas/inkText/inkRectangle),
// replacing the plain-text vanilla mail-thumbnail list entirely for the
// Biz tab -- these ink widgets ARE the buttons now (registered click
// callbacks via CorpoBizWebUIAction), not just a decorative overlay
// sitting on top of separately-clickable vanilla rows. This sidesteps
// the vanilla mail-thumbnail list's widget-dedup-by-name caching
// quirks entirely (stale text on an unchanged key, reordering on a
// changed key -- see TerminalUI.reds's RoleStatusEntry/RoleModelEntry
// history) since we fully tear down and rebuild our own tree on every
// state change, with no opaque cache fighting us. Generic over any
// BizDef/Resource/BizRoleDef -- no business-specific code here.
//
// inkWidget/inkCanvas/inkText/inkRectangle are native engine classes the
// redscript compiler has real type info for (unlike WolvenKit-authored
// widget archives, which this file deliberately avoids needing), so
// every method name/signature below is checked by the actual compiler --
// confirmed working names, found by letting real compile errors correct
// wrong guesses (SetAnchor only takes a real inkEAnchor member --
// "TopLeft"/"Fill" work, "TopFillHorizontally" doesn't; tearing down a
// previous widget is root.RemoveChild(widget), not widget.Unparent() or
// widget.RemoveFromParent(), neither of which exist here). What's NOT
// compiler-checked is *layout* -- is this actually positioned/sized/
// colored the way it's meant to look -- which can only be confirmed by
// actually looking at it in-game.
public class CorpoBizWebUI {

  public static func RootWidgetName() -> CName {
    return n"corpobiz_web_dashboard";
  }

  // Tears down any previous instance (if the page was already open and
  // is being refreshed) and builds a fresh dashboard filling the Mail/
  // Biz tab's own canvas. Called both from TerminalUI's
  // InitializeMailsThumbnails wrap AND from CorpoBizWebUIAction.OnRelease
  // after every click -- we own our own refresh now, no dependency on
  // RequestMailThumbnailWidgetsUpdate().
  public static func Render(controller: wref<ComputerInkGameController>, game: GameInstance, def: BizDef) -> Void {
    // GetRootCompoundWidget() turned out to be a SIBLING of indexFrame
    // (the container holding each tab's own canvas --
    // internet/menu_files/menu_mails/menuNewsFeed/mainMenu), not an
    // ancestor of it -- confirmed live via RedHotTools' Ink Inspector.
    // Reparenting onto menu_mails (the actual Mail/Biz tab's own canvas)
    // instead means the game's native tab show/hide logic covers our
    // visibility for free.
    let rawRoot = controller.GetRootCompoundWidget();
    let target = CorpoBizWebUI.FindMailCanvas(rawRoot);
    if !IsDefined(target) {
      return;
    }

    CorpoBizWebUI.Clear(target);

    // target.GetSize() returns (1,1) live -- menu_mails is itself
    // Fill-anchored with no literal stored size, so GetSize() reports a
    // placeholder, not its real resolved on-screen footprint. Don't
    // query size at all -- Fill-anchor ourselves (confirmed real via
    // Codeware's own AlignToFill() utility: inkEAnchor.Fill), and use a
    // fixed design-width constant for inner content layout instead of a
    // runtime-queried one.
    let contentWidth = 860.0;

    let dash = new inkCanvas();
    dash.SetName(CorpoBizWebUI.RootWidgetName());
    dash.SetAnchor(inkEAnchor.Fill);
    dash.Reparent(target);

    let backdrop = new inkRectangle();
    backdrop.SetAnchor(inkEAnchor.Fill);
    backdrop.SetTintColor(new HDRColor(0.05, 0.04, 0.07, 0.92));
    backdrop.Reparent(dash);

    if !CorpoBizState.IsOwned(game, def.id) {
      CorpoBizWebUI.RenderBuyPage(dash, controller, game, def, contentWidth);
      return;
    }

    let mod = TerminalUI.FindBiz(controller);
    let view = CorpoBizState.GetUIView(game, def.id);
    if view == 1 {
      CorpoBizWebUI.RenderStaffPage(dash, controller, game, mod, def, contentWidth);
    } else if view == 2 {
      CorpoBizWebUI.RenderStockPage(dash, controller, game, def, contentWidth);
    } else {
      CorpoBizWebUI.RenderHomePage(dash, controller, game, def, contentWidth);
    }
  }

  private static func RenderBuyPage(dash: ref<inkCanvas>, controller: wref<ComputerInkGameController>, game: GameInstance, def: BizDef, contentWidth: Float) -> Void {
    let y = 20.0;
    CorpoBizWebUI.AddLabel(dash, 24.0, y, def.displayName, 32, new HDRColor(1.0, 0.18, 0.48, 1.0));
    y += 60.0;
    CorpoBizWebUI.AddButton(dash, controller, game, 24.0, y, contentWidth, 44.0, "Buy " + def.displayName + " -- $" + ToString(def.purchasePrice), new HDRColor(1.0, 1.0, 1.0, 1.0), n"buy", n"");
  }

  private static func RenderHomePage(dash: ref<inkCanvas>, controller: wref<ComputerInkGameController>, game: GameInstance, def: BizDef, contentWidth: Float) -> Void {
    let y = 20.0;
    CorpoBizWebUI.AddLabel(dash, 24.0, y, def.displayName, 32, new HDRColor(1.0, 0.18, 0.48, 1.0));
    y += 60.0;

    CorpoBizWebUI.AddButton(dash, controller, game, 24.0, y, contentWidth, 44.0, def.displayName + " -- OWNED", new HDRColor(0.3, 0.9, 0.5, 1.0), n"noop", n"");
    y += 60.0;

    CorpoBizWebUI.AddButton(dash, controller, game, 24.0, y, contentWidth, 44.0, "Staff ->", new HDRColor(1.0, 1.0, 1.0, 1.0), n"nav_staff", n"");
    y += 56.0;
    CorpoBizWebUI.AddButton(dash, controller, game, 24.0, y, contentWidth, 44.0, "Stock ->", new HDRColor(1.0, 1.0, 1.0, 1.0), n"nav_stock", n"");
  }

  private static func RenderStaffPage(dash: ref<inkCanvas>, controller: wref<ComputerInkGameController>, game: GameInstance, mod: ref<BizModule>, def: BizDef, contentWidth: Float) -> Void {
    let y = 20.0;
    CorpoBizWebUI.AddLabel(dash, 24.0, y, "Staff", 28, new HDRColor(1.0, 0.18, 0.48, 1.0));
    y += 48.0;
    CorpoBizWebUI.AddButton(dash, controller, game, 24.0, y, 160.0, 36.0, "<- Back", new HDRColor(1.0, 1.0, 1.0, 1.0), n"nav_back", n"");
    y += 52.0;

    for role in def.roles {
      CorpoBizWebUI.AddRoleCard(dash, controller, game, def.id, mod, 24.0, y, contentWidth, role);
      y += 76.0;
    }
  }

  private static func RenderStockPage(dash: ref<inkCanvas>, controller: wref<ComputerInkGameController>, game: GameInstance, def: BizDef, contentWidth: Float) -> Void {
    let y = 20.0;
    CorpoBizWebUI.AddLabel(dash, 24.0, y, "Stock", 28, new HDRColor(1.0, 0.18, 0.48, 1.0));
    y += 48.0;
    CorpoBizWebUI.AddButton(dash, controller, game, 24.0, y, 160.0, 36.0, "<- Back", new HDRColor(1.0, 1.0, 1.0, 1.0), n"nav_back", n"");
    y += 52.0;

    let cash = CorpoBizState.GetAccruedCash(game, def.id);
    if CorpoBiz.HasPrimaryResource(def) {
      let resource = CorpoBiz.PrimaryResource(def);
      let level = CorpoBizState.GetSupplyLevel(game, def.id, resource);
      CorpoBizWebUI.AddLabel(dash, 24.0, y, resource.DisplayName() + ": " + ToString(level.currentQuantity) + " / " + ToString(level.maxQuantity), 18, new HDRColor(1.0, 1.0, 1.0, 1.0));
      y += 30.0;
      CorpoBizWebUI.AddMeterBar(dash, 24.0, y, contentWidth, level.currentQuantity, level.maxQuantity);
      y += 34.0;

      let restockLabel = "Restock " + resource.DisplayName() + " +30 -- $" + ToString(def.restockCostPer10Percent * 3);
      if level.currentQuantity >= level.maxQuantity {
        restockLabel = resource.DisplayName() + " stock full (" + ToString(level.maxQuantity) + ")";
      }
      CorpoBizWebUI.AddButton(dash, controller, game, 24.0, y, contentWidth, 44.0, restockLabel, new HDRColor(1.0, 1.0, 1.0, 1.0), n"restock", n"");
      y += 56.0;
    }

    CorpoBizWebUI.AddLabel(dash, 24.0, y, "Uncollected cash: $" + ToString(cash), 20, new HDRColor(1.0, 0.82, 0.25, 1.0));
    y += 34.0;
    let collectLabel = "Collect $" + ToString(cash);
    if cash <= 0 {
      collectLabel = "No cash to collect";
    }
    CorpoBizWebUI.AddButton(dash, controller, game, 24.0, y, contentWidth, 44.0, collectLabel, new HDRColor(1.0, 1.0, 1.0, 1.0), n"collect", n"");
  }

  // Climbs from the controller's root (a sibling of indexFrame) up to
  // their common parent, then down into indexFrame/menu_mails -- the
  // Mail/Biz tab's own canvas.
  private static func FindMailCanvas(root: wref<inkCompoundWidget>) -> wref<inkCompoundWidget> {
    let commonParent = root.GetParentWidget() as inkCompoundWidget;
    if !IsDefined(commonParent) {
      return null;
    }
    let indexFrame = commonParent.GetWidgetByPathName(n"indexFrame") as inkCompoundWidget;
    if !IsDefined(indexFrame) {
      return null;
    }
    return indexFrame.GetWidgetByPathName(n"menu_mails") as inkCompoundWidget;
  }

  public static func Clear(target: wref<inkCompoundWidget>) -> Void {
    let existing = target.GetWidgetByPathName(CorpoBizWebUI.RootWidgetName());
    if IsDefined(existing) {
      target.RemoveChild(existing);
    }
  }

  private static func AddLabel(parent: ref<inkCanvas>, x: Float, y: Float, text: String, fontSize: Int32, color: HDRColor) -> Void {
    let label = new inkText();
    label.SetAnchor(inkEAnchor.TopLeft);
    label.SetMargin(x, y, 0.0, 0.0);
    label.SetText(text);
    label.SetFontSize(fontSize);
    label.SetTintColor(color);
    label.Reparent(parent);
  }

  // A clickable row: a background rectangle plus a label, with a click
  // callback registered via CorpoBizWebUIAction (an instance, since
  // RegisterToCallback needs a target object, not a static function).
  // kind == n"noop" renders a label-only row with no click behavior
  // (used for the "-- OWNED" status row).
  private static func AddButton(parent: ref<inkCanvas>, controller: wref<ComputerInkGameController>, game: GameInstance, x: Float, y: Float, width: Float, height: Float, text: String, textColor: HDRColor, kind: CName, roleId: CName) -> Void {
    let btn = new inkRectangle();
    btn.SetAnchor(inkEAnchor.TopLeft);
    btn.SetMargin(x, y, 0.0, 0.0);
    btn.SetSize(new Vector2(width, height));
    btn.SetTintColor(new HDRColor(0.14, 0.14, 0.17, 0.95));
    btn.Reparent(parent);

    CorpoBizWebUI.AddLabel(parent, x + 14.0, y + height / 2.0 - 11.0, text, 18, textColor);

    if !Equals(kind, n"noop") {
      let action = new CorpoBizWebUIAction();
      action.controller = controller;
      action.game = game;
      action.kind = kind;
      action.roleId = roleId;
      btn.RegisterToCallback(n"OnRelease", action, n"OnRelease");
    }
  }

  // One meter row: a dark track rectangle, and a tinted fill rectangle
  // scaled to currentQuantity/maxQuantity.
  private static func AddMeterBar(parent: ref<inkCanvas>, x: Float, y: Float, width: Float, current: Int32, max: Int32) -> Void {
    let track = new inkRectangle();
    track.SetAnchor(inkEAnchor.TopLeft);
    track.SetMargin(x, y, 0.0, 0.0);
    track.SetSize(new Vector2(width, 14.0));
    track.SetTintColor(new HDRColor(0.15, 0.15, 0.18, 1.0));
    track.Reparent(parent);

    let fraction = 0.0;
    if max > 0 {
      fraction = Cast<Float>(current) / Cast<Float>(max);
    }
    let fill = new inkRectangle();
    fill.SetAnchor(inkEAnchor.TopLeft);
    fill.SetMargin(x, y, 0.0, 0.0);
    fill.SetSize(new Vector2(width * fraction, 14.0));
    fill.SetTintColor(new HDRColor(1.0, 0.18, 0.48, 1.0));
    fill.Reparent(parent);
  }

  // A clickable card per role: hire/fire on the main body, a smaller
  // style-cycle button alongside it.
  private static func AddRoleCard(parent: ref<inkCanvas>, controller: wref<ComputerInkGameController>, game: GameInstance, bizId: CName, mod: ref<BizModule>, x: Float, y: Float, width: Float, role: BizRoleDef) -> Void {
    let hired = CorpoBizState.IsRoleHired(game, bizId, role.id);
    let status = "$" + ToString(role.hireCost) + " to hire";
    let color = new HDRColor(0.7, 0.7, 0.75, 1.0);
    if hired {
      status = "HIRED (tap to fire)";
      color = new HDRColor(0.3, 0.9, 0.5, 1.0);
    }
    let styleWidth = 140.0;
    let hireWidth = width - styleWidth - 12.0;
    CorpoBizWebUI.AddButton(parent, controller, game, x, y, hireWidth, 44.0, NameToString(role.id) + " -- " + status, color, n"hire_fire", role.id);

    let variant = CorpoBizState.GetRoleVariant(game, bizId, role.id);
    let variantName = mod.RoleVariantName(role.id, variant);
    CorpoBizWebUI.AddButton(parent, controller, game, x + hireWidth + 12.0, y, styleWidth, 44.0, "Look: " + variantName, new HDRColor(0.7, 0.7, 0.75, 1.0), n"style", role.id);
  }
}

// Click target for every CorpoBizWebUI button -- a small instance per
// button (RegisterToCallback needs a real object to call a method on,
// not a static function) carrying just enough context to perform the
// action and re-render. Re-resolves mod/def fresh via TerminalUI.FindBiz
// rather than caching them, since staff can be hired/fired and stock
// consumed between when a button was built and when it's actually
// clicked.
public class CorpoBizWebUIAction extends IScriptable {
  public let controller: wref<ComputerInkGameController>;
  public let game: GameInstance;
  public let kind: CName;
  public let roleId: CName;

  public cb func OnRelease(e: wref<inkPointerEvent>) -> Bool {
    if !e.IsAction(n"click") {
      return false;
    }

    let mod = TerminalUI.FindBiz(this.controller);
    if !IsDefined(mod) {
      return false;
    }
    let def = mod.Def();
    CorpoBiz.Settle(this.game, def);
    let player = GameInstance.GetPlayerSystem(this.game).GetLocalPlayerMainGameObject();

    if Equals(this.kind, n"buy") {
      CorpoBiz.TryBuy(this.game, player, def);
    } else if Equals(this.kind, n"nav_staff") {
      CorpoBizState.SetUIView(this.game, def.id, 1);
    } else if Equals(this.kind, n"nav_stock") {
      CorpoBizState.SetUIView(this.game, def.id, 2);
    } else if Equals(this.kind, n"nav_back") {
      CorpoBizState.SetUIView(this.game, def.id, 0);
    } else if Equals(this.kind, n"hire_fire") {
      if CorpoBizState.IsRoleHired(this.game, def.id, this.roleId) {
        CorpoBiz.TryFireRole(this.game, def.id, this.roleId);
      } else {
        for role in def.roles {
          if Equals(role.id, this.roleId) {
            CorpoBiz.TryHireRole(this.game, player, def.id, role);
          }
        }
      }
    } else if Equals(this.kind, n"style") {
      CorpoBiz.CycleRoleVariant(this.game, def.id, this.roleId, mod.RoleVariantCount(this.roleId));
    } else if Equals(this.kind, n"restock") {
      if CorpoBiz.HasPrimaryResource(def) {
        CorpoBiz.TryRestock(this.game, player, def, CorpoBiz.PrimaryResource(def));
      }
    } else if Equals(this.kind, n"collect") {
      CorpoBiz.TryCollect(this.game, player, def.id);
    }

    CorpoBizWebUI.Render(this.controller, this.game, mod.Def());
    return true;
  }
}
