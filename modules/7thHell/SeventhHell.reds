module CorpoBiz.SeventhHell
import CorpoBiz.*

// The first business installed on the CorpoBiz framework: the nightclub
// 7th Hell, unlocked after the side gig "An Inconvenient Killer".
public class SeventhHellModule extends BizModule {

  public func Def() -> BizDef {
    // Scalar/Vector4 fields assigned BEFORE any array-of-struct field on
    // this same struct -- see Registry.reds's debug findings: every
    // module's terminalPosition was reading back as zero, including
    // this one, which was never touched by today's changes. Suspected
    // cause: an array<Struct> literal assignment (def.prereqs/def.roles)
    // immediately followed by a Vector4 assignment on the same struct
    // corrupts/zeroes that next assignment in this redscript build.
    // Untested beyond this reordering actually fixing the symptom.
    let def: BizDef;
    def.id = n"seventh_hell";
    def.displayName = "7th Hell";
    def.purchasePrice = 15000;
    def.terminalPosition = new Vector4(-1939.11, -49.75, -0.45, 1.0);
    def.restockCostPer10Percent = 150;
    def.stockDecayPerDayPerActiveRole = 8;
    def.prereqs = [this.GigDonePrereq()];
    def.roles = [this.GetRole(n"bouncer"), this.GetRole(n"dj"), this.GetRole(n"dancer")];
    def.inputs = [this.AlcoholResource()];
    def.outputs = [];
    return def;
  }

  // The real internal resource path for the gig "An Inconvenient Killer"
  // (confirmed via community quest-id docs, then verified live in-game via
  // the CET console: `GameInstance.GetJournalManager(game)
  // .GetEntryByString(path, "gameJournalQuest")` resolves this path and
  // `.GetEntryState(entry)` correctly reported `Succeeded` after finishing
  // it) -- replaces the earlier self-asserted "pretend this is done" Fact,
  // which is no longer needed now that the real journal state is checked.
  private func GigDonePrereq() -> BizPrereq {
    let p: BizPrereq;
    p.kind = BizPrereqKind.Gig;
    p.gigPath = "quests/street_stories/city_center/downtown/sts_cct_dtn_02";
    return p;
  }

  // quantityPerDay isn't consumed by any recipe-execution logic yet
  // (CorpoBiz.Settle still uses the older stock-percentage decay formula,
  // keyed off stockDecayPerDayPerActiveRole, not a per-resource rate) --
  // 24/day (one drink an hour per active shift) is illustrative, not yet
  // load-bearing, until Settle catches up to the Resource model.
  // maxQuantity = 100 preserves the original 0-100 "percent" stock scale.
  private func AlcoholResource() -> ref<Resource> {
    return SimpleResource.Create(n"alcohol", "Alcohol", 24, 100);
  }

  // array<CName> works fine (native element type); array<RoleDef>-shaped
  // things do not compile in this redscript build ("has no members" on
  // PushBack for any user-defined struct), so roles are looked up
  // individually by id rather than collected into an array and iterated
  // with methods.
  public func GetRole(id: CName) -> BizRoleDef {
    if Equals(id, n"bouncer") {
      return MakeBizRole(n"bouncer", r"base/characters/entities/gang/gang__cyberpunk_ma.ent", -1941.50, -57.13, 7.45, -74.15, 400, 150);
    }
    if Equals(id, n"dj") {
      return MakeBizRole(n"dj", r"base/characters/entities/citizen/citizen__rich_ma.ent", -1912.52, -42.24, -0.53, 91.80, 350, 200);
    }
    return MakeBizRole(n"dancer", r"base/quest/main_quests/prologue/q004/lizzies_club/characters/lizzies_customer_female_middle_bd.ent", -1928.49, -42.23, -0.69, 86.20, 350, 200);
  }

}

// Self-registration: base/Registry.reds never names this module, so this
// module is responsible for announcing itself. @wrapMethod is designed to
// let independent files each wrap the same vanilla method without
// conflict (base/StaffSpawner.reds wraps this exact method too, for its
// own unrelated purpose) -- wrappedMethod() chains to whatever else is
// also wrapping it, vanilla behavior included.
@wrapMethod(ScriptedPuppet)
protected cb func OnGameAttached() -> Void {
  wrappedMethod();
  if this.IsPlayer() && CoopBridge.IsLocalPlayer(this.GetEntityID()) {
    CorpoBizRegistry.Register(this.GetGame(), new SeventhHellModule());
  }
}
