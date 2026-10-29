module CorpoBiz

// Injects a synthetic entry into the Mail tab of any computer terminal
// standing near a registered business module's terminal position, turning
// it into that business's menu. Reuses the vanilla mail-thumbnail widget
// definition so no new UI assets are needed; a sentinel folderID marks our
// entries so OnDocumentThumbnailCallback can intercept clicks before the
// real document-open logic runs. Generic over every module in
// CorpoBizRegistry.All() -- a second business's terminal, anywhere else in
// the world, gets this same "Biz" tab automatically.
//
// array<SDocumentThumbnailWidgetPackage> has no callable methods in this
// redscript build (PushBack/Size/etc. all fail with "has no members", for
// any struct element type, confirmed via an isolated minimal repro) - so for
// our terminal we skip wrappedMethod() entirely and replace the whole list
// via a single array *literal* assignment instead, which is a different
// compiler code path than a method call. Every other terminal in the game is
// unaffected and still gets its real mail list via wrappedMethod().
//
// Role-listing rows (Staff page) are built via count-based branching rather
// than a loop, for the same reason: array<SDocumentThumbnailWidgetPackage>
// literals are fixed-size at the call site, with no way to append more
// elements dynamically. This supports modules with 0-4 roles; a module
// needing more would need another branch added below.
public class TerminalUI {

  public static func TerminalMatchRadius() -> Float {
    return 5.0;
  }

  public static func SentinelFolderId() -> Int32 {
    return -777;
  }

  public static func FindBiz(controller: ref<ComputerInkGameController>) -> ref<BizModule> {
    let ownerPos = controller.GetOwner().GetWorldPosition();
    let game = controller.GetOwner().GetGame();
    return CorpoBizRegistry.FindByPosition(game, ownerPos, TerminalUI.TerminalMatchRadius());
  }

  public static func HandleSelection(game: GameInstance, player: ref<GameObject>, mod: ref<BizModule>, documentID: Int32) -> Void {
    let def = mod.Def();
    CorpoBiz.Settle(game, def);
    let view = CorpoBizState.GetUIView(game, def.id);
    if view == 1 {
      TerminalUI.HandleStaffSelection(game, player, mod, def, documentID);
    } else if view == 2 {
      TerminalUI.HandleStockSelection(game, player, def, documentID);
    } else {
      TerminalUI.HandleHomeSelection(game, player, def, documentID);
    }
  }

  private static func HandleHomeSelection(game: GameInstance, player: ref<GameObject>, def: BizDef, documentID: Int32) -> Void {
    if documentID == 0 {
      CorpoBiz.TryBuy(game, player, def);
      return;
    }
    if !CorpoBizState.IsOwned(game, def.id) {
      return;
    }
    if documentID == 1 {
      CorpoBizState.SetUIView(game, def.id, 1);
    } else if documentID == 2 {
      CorpoBizState.SetUIView(game, def.id, 2);
    }
  }

  private static func HandleStaffSelection(game: GameInstance, player: ref<GameObject>, mod: ref<BizModule>, def: BizDef, documentID: Int32) -> Void {
    if documentID == 0 {
      CorpoBizState.SetUIView(game, def.id, 0);
      return;
    }
    let idx = 0;
    for role in def.roles {
      idx += 1;
      if documentID == idx * 2 - 1 {
        if CorpoBizState.IsRoleHired(game, def.id, role.id) {
          CorpoBiz.TryFireRole(game, def.id, role.id);
        } else {
          CorpoBiz.TryHireRole(game, player, def.id, role);
        }
        return;
      }
      if documentID == idx * 2 {
        CorpoBiz.CycleRoleVariant(game, def.id, role.id, mod.RoleVariantCount(role.id));
        return;
      }
    }
  }

  private static func HandleStockSelection(game: GameInstance, player: ref<GameObject>, def: BizDef, documentID: Int32) -> Void {
    if documentID == 0 {
      CorpoBizState.SetUIView(game, def.id, 0);
      return;
    }
    if documentID == 2 && CorpoBiz.HasPrimaryResource(def) {
      CorpoBiz.TryRestock(game, player, def, CorpoBiz.PrimaryResource(def).id);
    } else if documentID == 3 {
      CorpoBiz.TryCollect(game, player, def.id);
    }
  }

  // widgetKey must be unique across every entry we ever hand to the Mail
  // panel (not just within one view, and not just within one business): the
  // game's own dedup logic (GetFileThumbnailWidgetDataIndex in
  // computerMenuController.script) matches cached widgets by
  // ownerID+widgetName+widgetTweakDBID+libraryPath+libraryID, NOT by
  // documentAdress. Since every row shares the same tweakDBID/library fields
  // (reusing the one vanilla mail-thumbnail widget), leaving widgetName at
  // its default empty string made every row match the first one that got
  // cached -- each new row just overwrote the same physical widget instead
  // of creating its own.
  public static func MakeEntry(documentID: Int32, widgetKey: String, name: String) -> SDocumentThumbnailWidgetPackage {
    let pkg: SDocumentThumbnailWidgetPackage;
    pkg.widgetTweakDBID = t"DevicesUIDefinitions.MailThumbnailWidget";
    pkg.libraryID = n"mailThumbnail";
    pkg.libraryPath = r"base/gameplay/gui/world/computers/computer.inkwidget";
    pkg.widgetName = widgetKey;
    pkg.displayName = name;
    pkg.folderName = name;
    pkg.documentAdress.folderID = TerminalUI.SentinelFolderId();
    pkg.documentAdress.documentID = documentID;
    pkg.documentType = EDocumentType.MAIL;
    pkg.isValid = true;
    return pkg;
  }

  // Three pages, navigated by clicking entries within the same list (no new
  // widgets available) and remembered via CorpoBizState.GetUIView: Home (buy
  // / nav), Staff (hire, fire, change look per role), Stock (level /
  // restock / collect).
  public static func Dashboard(game: GameInstance, mod: ref<BizModule>) -> array<SDocumentThumbnailWidgetPackage> {
    let def = mod.Def();
    let view = CorpoBizState.GetUIView(game, def.id);
    if view == 1 {
      return TerminalUI.StaffDashboard(game, mod, def);
    }
    if view == 2 {
      return TerminalUI.StockDashboard(game, def);
    }
    return TerminalUI.HomeDashboard(game, def);
  }

  public static func HomeDashboard(game: GameInstance, def: BizDef) -> array<SDocumentThumbnailWidgetPackage> {
    if !CorpoBizState.IsOwned(game, def.id) {
      return [TerminalUI.DashboardBuyEntry(game, def)];
    }
    return [
      TerminalUI.DashboardBuyEntry(game, def),
      TerminalUI.MakeEntry(1, "home_staff", "Staff ->"),
      TerminalUI.MakeEntry(2, "home_stock", "Stock ->")
    ];
  }

  public static func DashboardBuyEntry(game: GameInstance, def: BizDef) -> SDocumentThumbnailWidgetPackage {
    if CorpoBizState.IsOwned(game, def.id) {
      return TerminalUI.MakeEntry(0, "home_buy", def.displayName + " -- OWNED");
    }
    return TerminalUI.MakeEntry(0, "home_buy", "Buy " + def.displayName + " -- $" + ToString(def.purchasePrice));
  }

  public static func StaffDashboard(game: GameInstance, mod: ref<BizModule>, def: BizDef) -> array<SDocumentThumbnailWidgetPackage> {
    let count = 0;
    for role in def.roles {
      count += 1;
    }

    let r1: BizRoleDef;
    let r2: BizRoleDef;
    let r3: BizRoleDef;
    let r4: BizRoleDef;
    let idx = 0;
    for role in def.roles {
      idx += 1;
      if idx == 1 { r1 = role; } else if idx == 2 { r2 = role; } else if idx == 3 { r3 = role; } else if idx == 4 { r4 = role; }
    }

    let back = TerminalUI.MakeEntry(0, "staff_back", "<- Back");
    if count <= 0 {
      return [back];
    }
    if count == 1 {
      return [back, TerminalUI.RoleStatusEntry(game, def, 1, r1), TerminalUI.RoleModelEntry(game, mod, def, 1, r1)];
    }
    if count == 2 {
      return [
        back,
        TerminalUI.RoleStatusEntry(game, def, 1, r1), TerminalUI.RoleModelEntry(game, mod, def, 1, r1),
        TerminalUI.RoleStatusEntry(game, def, 2, r2), TerminalUI.RoleModelEntry(game, mod, def, 2, r2)
      ];
    }
    if count == 3 {
      return [
        back,
        TerminalUI.RoleStatusEntry(game, def, 1, r1), TerminalUI.RoleModelEntry(game, mod, def, 1, r1),
        TerminalUI.RoleStatusEntry(game, def, 2, r2), TerminalUI.RoleModelEntry(game, mod, def, 2, r2),
        TerminalUI.RoleStatusEntry(game, def, 3, r3), TerminalUI.RoleModelEntry(game, mod, def, 3, r3)
      ];
    }
    return [
      back,
      TerminalUI.RoleStatusEntry(game, def, 1, r1), TerminalUI.RoleModelEntry(game, mod, def, 1, r1),
      TerminalUI.RoleStatusEntry(game, def, 2, r2), TerminalUI.RoleModelEntry(game, mod, def, 2, r2),
      TerminalUI.RoleStatusEntry(game, def, 3, r3), TerminalUI.RoleModelEntry(game, mod, def, 3, r3),
      TerminalUI.RoleStatusEntry(game, def, 4, r4), TerminalUI.RoleModelEntry(game, mod, def, 4, r4)
    ];
  }

  public static func RoleStatusEntry(game: GameInstance, def: BizDef, idx: Int32, role: BizRoleDef) -> SDocumentThumbnailWidgetPackage {
    let docId = idx * 2 - 1;
    let key = "staff_status_" + NameToString(role.id);
    if CorpoBizState.IsRoleHired(game, def.id, role.id) {
      return TerminalUI.MakeEntry(docId, key, NameToString(role.id) + ": HIRED (tap to fire)");
    }
    return TerminalUI.MakeEntry(docId, key, "Hire " + NameToString(role.id) + " -- $" + ToString(role.hireCost));
  }

  public static func RoleModelEntry(game: GameInstance, mod: ref<BizModule>, def: BizDef, idx: Int32, role: BizRoleDef) -> SDocumentThumbnailWidgetPackage {
    let docId = idx * 2;
    let variant = CorpoBizState.GetRoleVariant(game, def.id, role.id);
    let variantName = mod.RoleVariantName(role.id, variant);
    return TerminalUI.MakeEntry(docId, "staff_model_" + NameToString(role.id), "   Look: " + variantName + " (tap to change)");
  }

  public static func StockDashboard(game: GameInstance, def: BizDef) -> array<SDocumentThumbnailWidgetPackage> {
    let cash = CorpoBizState.GetAccruedCash(game, def.id);
    if !CorpoBiz.HasPrimaryResource(def) {
      return [
        TerminalUI.MakeEntry(0, "stock_back", "<- Back"),
        TerminalUI.MakeEntry(1, "stock_status", "Uncollected cash: $" + ToString(cash)),
        TerminalUI.CollectEntry(game, def)
      ];
    }
    let resource = CorpoBiz.PrimaryResource(def);
    let stock = CorpoBizState.GetStock(game, def.id, resource.id);
    return [
      TerminalUI.MakeEntry(0, "stock_back", "<- Back"),
      TerminalUI.MakeEntry(1, "stock_status", resource.displayName + ": " + ToString(stock) + "%  |  Uncollected cash: $" + ToString(cash)),
      TerminalUI.RestockEntry(game, def, resource),
      TerminalUI.CollectEntry(game, def)
    ];
  }

  public static func RestockEntry(game: GameInstance, def: BizDef, resource: BizResource) -> SDocumentThumbnailWidgetPackage {
    let stock = CorpoBizState.GetStock(game, def.id, resource.id);
    if stock >= 100 {
      return TerminalUI.MakeEntry(2, "stock_restock", resource.displayName + " stock full (100%)");
    }
    return TerminalUI.MakeEntry(2, "stock_restock", "Restock " + resource.displayName + " +30% -- $" + ToString(def.restockCostPer10Percent * 3));
  }

  public static func CollectEntry(game: GameInstance, def: BizDef) -> SDocumentThumbnailWidgetPackage {
    let cash = CorpoBizState.GetAccruedCash(game, def.id);
    if cash <= 0 {
      return TerminalUI.MakeEntry(3, "stock_collect", "No cash to collect");
    }
    return TerminalUI.MakeEntry(3, "stock_collect", "Collect $" + ToString(cash));
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

@wrapMethod(ComputerInkGameController)
protected func InitializeMailsThumbnails(widgetsData: script_ref<array<SDocumentThumbnailWidgetPackage>>) -> Void {
  let game = this.GetOwner().GetGame();
  let mod = TerminalUI.FindBiz(this);
  if IsDefined(mod) {
    widgetsData = TerminalUI.Dashboard(game, mod);
  }
  wrappedMethod(widgetsData);
}

// The top tab bar. Reconstructed wholesale for a matched business's
// terminal (Web + Network, matching what GetMenuButtonWidgets() would
// normally build, plus a new "Biz" tab) since array<Struct> has no
// PushBack to append to whatever the real call already built. "Biz" reuses
// widgetName "mails" so GoToMenu's built-in ShowMenuByName/HideMenuByName
// dispatch (which only recognizes a fixed set of hardcoded names) routes it
// to the Mail panel we already drive above -- no new content panel needed.
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

@wrapMethod(ComputerInkGameController)
protected cb func OnDocumentThumbnailCallback(e: wref<inkPointerEvent>) -> Bool {
  if e.IsAction(n"click") || e.IsAction(n"click_devices") || e.IsAction(n"tap") {
    let controller = e.GetCurrentTarget().GetController() as ComputerDocumentThumbnailWidgetController;
    if IsDefined(controller) {
      let address = controller.GetDocumentAdress();
      if Equals(address.folderID, TerminalUI.SentinelFolderId()) {
        let mod = TerminalUI.FindBiz(this);
        if IsDefined(mod) {
          let game = this.GetOwner().GetGame();
          let player = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject();
          TerminalUI.HandleSelection(game, player, mod, address.documentID);
          this.RequestMailThumbnailWidgetsUpdate();
        }
        return false;
      }
    }
  }
  return wrappedMethod(e);
}
