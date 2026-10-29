module Biz7thHell

// Injects a synthetic entry into the Mail tab of any computer terminal
// standing near 7th Hell's real in-world terminal, turning it into our
// business menu. Reuses the vanilla mail-thumbnail widget definition so no
// new UI assets are needed; a sentinel folderID marks our entries so
// OnDocumentThumbnailCallback can intercept clicks before the real
// document-open logic runs.
//
// array<SDocumentThumbnailWidgetPackage> has no callable methods in this
// redscript build (PushBack/Size/etc. all fail with "has no members", for
// any struct element type, confirmed via an isolated minimal repro) - so for
// our terminal we skip wrappedMethod() entirely and replace the whole list
// via a single array *literal* assignment instead, which is a different
// compiler code path than a method call. Every other terminal in the game is
// unaffected and still gets its real mail list via wrappedMethod().
public class TerminalUI {

  public static func SentinelFolderId() -> Int32 {
    return -777;
  }

  public static func IsOurTerminal(controller: ref<ComputerInkGameController>) -> Bool {
    let ownerPos = controller.GetOwner().GetWorldPosition();
    return Vector4.Distance(ownerPos, Config.TerminalPosition()) < 5.0;
  }

  public static func HandleSelection(game: GameInstance, player: ref<GameObject>, documentID: Int32) -> Void {
    Economy.Settle(game);
    let view = State.GetUIView(game);
    let quests = GameInstance.GetQuestsSystem(game);
    quests.SetFact(n"biz7thhell_dbg_click_view", view);
    quests.SetFact(n"biz7thhell_dbg_click_docid", documentID);
    if view == 1 {
      TerminalUI.HandleStaffSelection(game, player, documentID);
    } else if view == 2 {
      TerminalUI.HandleStockSelection(game, player, documentID);
    } else {
      TerminalUI.HandleHomeSelection(game, player, documentID);
    }
  }

  private static func HandleHomeSelection(game: GameInstance, player: ref<GameObject>, documentID: Int32) -> Void {
    if documentID == 0 {
      Terminal.TryBuy(game, player);
      return;
    }
    if !State.IsOwned(game) {
      return;
    }
    if documentID == 1 {
      State.SetUIView(game, 1);
    } else if documentID == 2 {
      State.SetUIView(game, 2);
    }
  }

  private static func HandleStaffSelection(game: GameInstance, player: ref<GameObject>, documentID: Int32) -> Void {
    if documentID == 0 {
      State.SetUIView(game, 0);
      return;
    }
    let idx = 0;
    for id in Config.RoleIds() {
      idx += 1;
      if documentID == idx * 2 - 1 {
        if State.IsRoleHired(game, id) {
          Terminal.TryFireRole(game, id);
        } else {
          Terminal.TryHireRole(game, player, id);
        }
        return;
      }
      if documentID == idx * 2 {
        Terminal.CycleRoleVariant(game, id);
        return;
      }
    }
  }

  private static func HandleStockSelection(game: GameInstance, player: ref<GameObject>, documentID: Int32) -> Void {
    if documentID == 0 {
      State.SetUIView(game, 0);
      return;
    }
    if documentID == 2 {
      Terminal.TryRestock(game, player);
    } else if documentID == 3 {
      Terminal.TryCollect(game, player);
    }
  }

  // widgetKey must be unique across every entry we ever hand to the Mail
  // panel (not just within one view): the game's own dedup logic
  // (GetFileThumbnailWidgetDataIndex in computerMenuController.script)
  // matches cached widgets by ownerID+widgetName+widgetTweakDBID+libraryPath
  // +libraryID, NOT by documentAdress. Since every row shares the same
  // tweakDBID/library fields (reusing the one vanilla mail-thumbnail
  // widget), leaving widgetName at its default empty string made every row
  // match the first one that got cached -- each new row just overwrote the
  // same physical widget instead of creating its own, which is why only the
  // last entry in the array was ever visible.
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
  // widgets available) and remembered via State.GetUIView: Home (buy / nav),
  // Staff (hire, fire, change look per role), Stock (level + restock).
  public static func Dashboard(game: GameInstance) -> array<SDocumentThumbnailWidgetPackage> {
    let view = State.GetUIView(game);
    let quests = GameInstance.GetQuestsSystem(game);
    quests.SetFact(n"biz7thhell_dbg_dashboard_view", view);
    quests.SetFact(n"biz7thhell_dbg_dashboard_owned", State.IsOwned(game) ? 1 : 0);
    if view == 1 {
      quests.SetFact(n"biz7thhell_dbg_dashboard_count", 9);
      return TerminalUI.StaffDashboard(game);
    }
    if view == 2 {
      quests.SetFact(n"biz7thhell_dbg_dashboard_count", 3);
      return TerminalUI.StockDashboard(game);
    }
    quests.SetFact(n"biz7thhell_dbg_dashboard_count", State.IsOwned(game) ? 3 : 1);
    return TerminalUI.HomeDashboard(game);
  }

  public static func HomeDashboard(game: GameInstance) -> array<SDocumentThumbnailWidgetPackage> {
    if !State.IsOwned(game) {
      return [TerminalUI.DashboardBuyEntry(game)];
    }
    return [
      TerminalUI.DashboardBuyEntry(game),
      TerminalUI.MakeEntry(1, "home_staff", "Staff ->"),
      TerminalUI.MakeEntry(2, "home_stock", "Stock ->")
    ];
  }

  public static func DashboardBuyEntry(game: GameInstance) -> SDocumentThumbnailWidgetPackage {
    if State.IsOwned(game) {
      return TerminalUI.MakeEntry(0, "home_buy", "7th Hell -- OWNED");
    }
    return TerminalUI.MakeEntry(0, "home_buy", "Buy 7th Hell -- $" + ToString(Config.PurchasePrice()));
  }

  public static func StaffDashboard(game: GameInstance) -> array<SDocumentThumbnailWidgetPackage> {
    let idx = 0;
    let r1: CName;
    let r2: CName;
    let r3: CName;
    for id in Config.RoleIds() {
      idx += 1;
      if idx == 1 { r1 = id; } else if idx == 2 { r2 = id; } else { r3 = id; }
    }
    return [
      TerminalUI.MakeEntry(0, "staff_back", "<- Back"),
      TerminalUI.RoleStatusEntry(game, 1, r1),
      TerminalUI.RoleModelEntry(game, 1, r1),
      TerminalUI.RoleStatusEntry(game, 2, r2),
      TerminalUI.RoleModelEntry(game, 2, r2),
      TerminalUI.RoleStatusEntry(game, 3, r3),
      TerminalUI.RoleModelEntry(game, 3, r3)
    ];
  }

  public static func RoleStatusEntry(game: GameInstance, idx: Int32, id: CName) -> SDocumentThumbnailWidgetPackage {
    let role = Config.GetRole(id);
    let docId = idx * 2 - 1;
    let key = "staff_status_" + NameToString(id);
    if State.IsRoleHired(game, id) {
      return TerminalUI.MakeEntry(docId, key, NameToString(id) + ": HIRED (tap to fire)");
    }
    return TerminalUI.MakeEntry(docId, key, "Hire " + NameToString(id) + " -- $" + ToString(role.hireCost));
  }

  public static func RoleModelEntry(game: GameInstance, idx: Int32, id: CName) -> SDocumentThumbnailWidgetPackage {
    let docId = idx * 2;
    let variant = State.GetRoleVariant(game, id);
    return TerminalUI.MakeEntry(docId, "staff_model_" + NameToString(id), "   Look: " + Config.RoleVariantName(id, variant) + " (tap to change)");
  }

  public static func StockDashboard(game: GameInstance) -> array<SDocumentThumbnailWidgetPackage> {
    let stock = State.GetStock(game);
    let cash = State.GetAccruedCash(game);
    return [
      TerminalUI.MakeEntry(0, "stock_back", "<- Back"),
      TerminalUI.MakeEntry(1, "stock_status", "Stock: " + ToString(stock) + "%  |  Uncollected cash: $" + ToString(cash)),
      TerminalUI.RestockEntry(game),
      TerminalUI.CollectEntry(game)
    ];
  }

  public static func RestockEntry(game: GameInstance) -> SDocumentThumbnailWidgetPackage {
    let stock = State.GetStock(game);
    if stock >= 100 {
      return TerminalUI.MakeEntry(2, "stock_restock", "Stock full (100%)");
    }
    return TerminalUI.MakeEntry(2, "stock_restock", "Restock +30% -- $" + ToString(Config.RestockCostPer10Percent() * 3));
  }

  public static func CollectEntry(game: GameInstance) -> SDocumentThumbnailWidgetPackage {
    let cash = State.GetAccruedCash(game);
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
  let quests = GameInstance.GetQuestsSystem(game);
  quests.SetFact(n"biz7thhell_dbg_mails_hook_fired", 1);
  let dist = Vector4.Distance(this.GetOwner().GetWorldPosition(), Config.TerminalPosition());
  quests.SetFact(n"biz7thhell_dbg_mails_dist_x10", Cast<Int32>(dist * 10.0));

  if TerminalUI.IsOurTerminal(this) {
    quests.SetFact(n"biz7thhell_dbg_mails_matched", 1);
    widgetsData = TerminalUI.Dashboard(game);
  } else {
    quests.SetFact(n"biz7thhell_dbg_mails_matched", 0);
  }
  wrappedMethod(widgetsData);
}

// The top tab bar. Reconstructed wholesale for our terminal (Web + Network,
// matching what GetMenuButtonWidgets() would normally build, plus a new
// "Biz" tab) since array<Struct> has no PushBack to append to whatever the
// real call already built. "Biz" reuses widgetName "mails" so GoToMenu's
// built-in ShowMenuByName/HideMenuByName dispatch (which only recognizes a
// fixed set of hardcoded names) routes it to the Mail panel we already drive
// above -- no new content panel needed.
@wrapMethod(ComputerInkGameController)
protected func InitializeMenuButtons(widgetsData: script_ref<array<SComputerMenuButtonWidgetPackage>>) -> Void {
  if TerminalUI.IsOurTerminal(this) {
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
        let game = this.GetOwner().GetGame();
        let player = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject();
        TerminalUI.HandleSelection(game, player, address.documentID);
        this.RequestMailThumbnailWidgetsUpdate();
        return false;
      }
    }
  }
  return wrappedMethod(e);
}
