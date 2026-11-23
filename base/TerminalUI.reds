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

    // TEMPORARY DEBUG -- records every FindBiz call (so we can tell
    // "never called" from "called but didn't match") plus the actual
    // ownerPos it computed, as Facts readable from the CET console.
    // Facts only store Int32, so position components are x100 scaled --
    // divide by 100 when reading back. Remove once the matching issue is
    // resolved.
    let quests = GameInstance.GetQuestsSystem(game);
    quests.SetFact(n"corpobiz_debug_findbiz_calls", quests.GetFact(n"corpobiz_debug_findbiz_calls") + 1);
    quests.SetFact(n"corpobiz_debug_ownerpos_x", Cast<Int32>(ownerPos.X * 100.0));
    quests.SetFact(n"corpobiz_debug_ownerpos_y", Cast<Int32>(ownerPos.Y * 100.0));
    quests.SetFact(n"corpobiz_debug_ownerpos_z", Cast<Int32>(ownerPos.Z * 100.0));

    let result = CorpoBizRegistry.FindByPosition(game, ownerPos, TerminalUI.TerminalMatchRadius());
    quests.SetFact(n"corpobiz_debug_findbiz_matched", IsDefined(result) ? 1 : 0);
    return result;
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
        // TEMPORARY DEBUG -- pinning down a contradiction: the console
        // independently reads the "hired" Fact as 1 and staying 1, yet
        // clicking this row keeps charging money (only the hire branch
        // below does that). Logs exactly what this specific click sees,
        // right at the decision point. Remove once resolved.
        let quests = GameInstance.GetQuestsSystem(game);
        quests.SetFact(n"corpobiz_debug_staffclick_docid", documentID);
        quests.SetFact(n"corpobiz_debug_staffclick_idx", idx);
        let hiredNow = CorpoBizState.IsRoleHired(game, def.id, role.id);
        quests.SetFact(n"corpobiz_debug_staffclick_hired_before", hiredNow ? 1 : 0);
        // TEMPORARY DEBUG -- direct side-by-side comparison: read the
        // exact hardcoded Fact name the console check used, plus whether
        // def.id/role.id actually Equals() the literals we expect, right
        // here at the call site. If hardcoded_fact=1 but hired_before=0
        // above, def.id/role.id aren't what we think they are at this
        // point -- bizid_match/roleid_match pin down which one.
        quests.SetFact(n"corpobiz_debug_staffclick_hardcoded_fact", quests.GetFact(n"corpobiz_seventh_hell_role_bouncer_hired"));
        quests.SetFact(n"corpobiz_debug_staffclick_bizid_match", Equals(def.id, n"seventh_hell") ? 1 : 0);
        quests.SetFact(n"corpobiz_debug_staffclick_roleid_match", Equals(role.id, n"bouncer") ? 1 : 0);
        if hiredNow {
          quests.SetFact(n"corpobiz_debug_staffclick_branch", 2);
          CorpoBiz.TryFireRole(game, def.id, role.id);
        } else {
          quests.SetFact(n"corpobiz_debug_staffclick_branch", 1);
          CorpoBiz.TryHireRole(game, player, def.id, role);
        }
        // TEMPORARY DEBUG -- read the Fact back immediately after the
        // Hire/Fire call returns, in the same function call, to see
        // exactly what SetRoleHired's `hired ? 1 : 0` ternary actually
        // wrote (vs. what we expected based on which branch ran above).
        quests.SetFact(n"corpobiz_debug_staffclick_hired_after", CorpoBizState.IsRoleHired(game, def.id, role.id) ? 1 : 0);
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
      CorpoBiz.TryRestock(game, player, def, CorpoBiz.PrimaryResource(def));
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
      return TerminalUI.MakeEntry(0, "home_buy_owned", def.displayName + " -- OWNED");
    }
    return TerminalUI.MakeEntry(0, "home_buy_unowned", "Buy " + def.displayName + " -- $" + ToString(def.purchasePrice));
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

  // The widget key (3rd arg to MakeEntry) deliberately encodes the hired
  // state -- see MakeEntry's own comment: the game dedups cached widgets
  // by ownerID+widgetName+..., NOT by documentAddress or content, so a
  // key that stays the same across a hire/fire toggle gets its OLD cached
  // text reused forever instead of refreshing. Confirmed via debug Facts:
  // the underlying Fact genuinely flips 1<->0 correctly on click, but the
  // row kept showing stale text because the key never changed. Making the
  // key itself state-dependent forces the engine to treat a toggle as a
  // brand-new widget.
  public static func RoleStatusEntry(game: GameInstance, def: BizDef, idx: Int32, role: BizRoleDef) -> SDocumentThumbnailWidgetPackage {
    let docId = idx * 2 - 1;
    if CorpoBizState.IsRoleHired(game, def.id, role.id) {
      return TerminalUI.MakeEntry(docId, "staff_status_" + NameToString(role.id) + "_hired", NameToString(role.id) + ": HIRED (tap to fire)");
    }
    return TerminalUI.MakeEntry(docId, "staff_status_" + NameToString(role.id) + "_unhired", "Hire " + NameToString(role.id) + " -- $" + ToString(role.hireCost));
  }

  public static func RoleModelEntry(game: GameInstance, mod: ref<BizModule>, def: BizDef, idx: Int32, role: BizRoleDef) -> SDocumentThumbnailWidgetPackage {
    let docId = idx * 2;
    let variant = CorpoBizState.GetRoleVariant(game, def.id, role.id);
    let variantName = mod.RoleVariantName(role.id, variant);
    return TerminalUI.MakeEntry(docId, "staff_model_" + NameToString(role.id) + "_v" + ToString(variant), "   Look: " + variantName + " (tap to change)");
  }

  public static func StockDashboard(game: GameInstance, def: BizDef) -> array<SDocumentThumbnailWidgetPackage> {
    let cash = CorpoBizState.GetAccruedCash(game, def.id);
    if !CorpoBiz.HasPrimaryResource(def) {
      return [
        TerminalUI.MakeEntry(0, "stock_back", "<- Back"),
        TerminalUI.MakeEntry(1, "stock_status_" + ToString(cash), "Uncollected cash: $" + ToString(cash)),
        TerminalUI.CollectEntry(game, def)
      ];
    }
    let resource = CorpoBiz.PrimaryResource(def);
    let level = CorpoBizState.GetSupplyLevel(game, def.id, resource);
    return [
      TerminalUI.MakeEntry(0, "stock_back", "<- Back"),
      // Same state-in-key fix as RoleStatusEntry/RoleModelEntry above --
      // this row's text depends on level.currentQuantity/cash, which can
      // change (restock/collect) without the key changing otherwise.
      TerminalUI.MakeEntry(1, "stock_status_" + ToString(level.currentQuantity) + "_" + ToString(cash), resource.DisplayName() + ": " + ToString(level.currentQuantity) + "/" + ToString(level.maxQuantity) + "  |  Uncollected cash: $" + ToString(cash)),
      TerminalUI.RestockEntry(game, def, resource),
      TerminalUI.CollectEntry(game, def)
    ];
  }

  public static func RestockEntry(game: GameInstance, def: BizDef, resource: ref<Resource>) -> SDocumentThumbnailWidgetPackage {
    let level = CorpoBizState.GetSupplyLevel(game, def.id, resource);
    if level.currentQuantity >= level.maxQuantity {
      return TerminalUI.MakeEntry(2, "stock_restock_full", resource.DisplayName() + " stock full (" + ToString(level.maxQuantity) + ")");
    }
    return TerminalUI.MakeEntry(2, "stock_restock_" + ToString(level.currentQuantity), "Restock " + resource.DisplayName() + " +30 -- $" + ToString(def.restockCostPer10Percent * 3));
  }

  public static func CollectEntry(game: GameInstance, def: BizDef) -> SDocumentThumbnailWidgetPackage {
    let cash = CorpoBizState.GetAccruedCash(game, def.id);
    if cash <= 0 {
      return TerminalUI.MakeEntry(3, "stock_collect_empty", "No cash to collect");
    }
    return TerminalUI.MakeEntry(3, "stock_collect_" + ToString(cash), "Collect $" + ToString(cash));
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
    // Empty -- the ink dashboard (CorpoBizWebUI) is now the whole Biz
    // tab's display AND click handling (real inkRectangle buttons with
    // their own RegisterToCallback handlers), not a decorative overlay
    // on top of this vanilla thumbnail list anymore. TerminalUI.Dashboard/
    // HandleSelection and friends below are unused for Biz now but left
    // in place rather than ripped out in the same pass as a working
    // rewrite -- clean up once the ink UI is fully proven.
    let empty: array<SDocumentThumbnailWidgetPackage>;
    widgetsData = empty;
  }
  wrappedMethod(widgetsData);
  // Render AFTER wrappedMethod, not before -- menu_mails (the canvas
  // CorpoBizWebUI.FindMailCanvas looks for) is likely only actually
  // constructed by the vanilla method's own processing of widgetsData,
  // not before it. On a cold terminal-open this is the first-ever call,
  // so querying for menu_mails beforehand found nothing (target_found=0)
  // -- confirmed via debug Facts.
  if IsDefined(mod) {
    CorpoBizWebUI.Render(this, game, mod.Def());
  }
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
  // TEMPORARY DEBUG -- see FindBiz's own debug comment. This counts
  // calls to *this specific method* (and whether it matched) separately
  // from FindBiz's shared counter, since InitializeMailsThumbnails also
  // calls FindBiz and would otherwise be indistinguishable from this one.
  let quests = GameInstance.GetQuestsSystem(this.GetOwner().GetGame());
  quests.SetFact(n"corpobiz_debug_menubtns_calls", quests.GetFact(n"corpobiz_debug_menubtns_calls") + 1);

  let mod = TerminalUI.FindBiz(this);
  if IsDefined(mod) {
    quests.SetFact(n"corpobiz_debug_menubtns_matched", quests.GetFact(n"corpobiz_debug_menubtns_matched") + 1);
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
  // Was `e.IsAction(n"click") || e.IsAction(n"click_devices") || e.IsAction(n"tap")`
  // -- confirmed via debug Facts that a single mouse click delivers TWO
  // separate events to this callback, one satisfying "click" and a second
  // satisfying "click_devices" (dispatch counter went up by 2 per click,
  // with prev_action=1/click then last_action=2/click_devices) -- so
  // OR-ing both in meant every click ran HandleSelection twice, causing
  // real double charges (two independent RemoveItem calls both succeeding
  // before either's state write was visible to the other). Handling only
  // "click" here fixes mouse input; "tap" is kept for touch/gamepad,
  // unconfirmed whether it has the same double-fire issue as
  // "click_devices" did -- watch for it if controller input is ever
  // tested.
  if e.IsAction(n"click") || e.IsAction(n"tap") {
    let controller = e.GetCurrentTarget().GetController() as ComputerDocumentThumbnailWidgetController;
    if IsDefined(controller) {
      let address = controller.GetDocumentAdress();
      if Equals(address.folderID, TerminalUI.SentinelFolderId()) {
        let mod = TerminalUI.FindBiz(this);
        if IsDefined(mod) {
          let game = this.GetOwner().GetGame();
          let player = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject();
          // TEMPORARY DEBUG -- testing whether a single physical click
          // dispatches HandleSelection more than once (e.g. press+release
          // each separately satisfying IsAction checks). Counter plus
          // which action type matched, per dispatch. Remove once resolved.
          let quests = GameInstance.GetQuestsSystem(game);
          quests.SetFact(n"corpobiz_debug_thumbnail_dispatch_count", quests.GetFact(n"corpobiz_debug_thumbnail_dispatch_count") + 1);
          quests.SetFact(n"corpobiz_debug_thumbnail_last_docid", address.documentID);
          // Shift the previous dispatch's action into "prev" before
          // recording this one, so two back-to-back dispatches from one
          // click leave both actions readable afterward (otherwise the
          // second dispatch's write would clobber the first's before we
          // ever get to read it).
          quests.SetFact(n"corpobiz_debug_thumbnail_prev_action", quests.GetFact(n"corpobiz_debug_thumbnail_last_action"));
          if e.IsAction(n"click") {
            quests.SetFact(n"corpobiz_debug_thumbnail_last_action", 1);
          } else if e.IsAction(n"click_devices") {
            quests.SetFact(n"corpobiz_debug_thumbnail_last_action", 2);
          } else {
            quests.SetFact(n"corpobiz_debug_thumbnail_last_action", 3);
          }
          TerminalUI.HandleSelection(game, player, mod, address.documentID);
          this.RequestMailThumbnailWidgetsUpdate();
        }
        return false;
      }
    }
  }
  return wrappedMethod(e);
}
