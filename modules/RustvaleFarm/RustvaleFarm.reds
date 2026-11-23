module CorpoBiz.RustvaleFarm
import CorpoBiz.*

// Rustvale Farm -- first stage of a three-business supply chain
// (Farm -> Watson Distillery -> Northside Warehouse -> 7th Hell)
// prototyped in a browser-demo mockup before being ported here. Grows
// Grain; has no input resource of its own. No real-world site scouted
// yet -- terminalPosition and every role's position below are
// placeholders (see Def() and GetRole()), same TODO status 7th Hell's
// own anchors started from.
//
// Design gap, carried over deliberately rather than papered over: in the
// demo, Farmers set Grain's *production rate*, not a per-role cash
// number -- hiring more of them grows output, and the business turns a
// profit by automatically selling off whatever overflows a downstream
// buffer, not from a flat daily wage paid back as revenue.
// CorpoBiz.Settle only knows "flat revenuePerDay per hired role,
// optionally scaled by one resource's fill fraction" -- it has no concept
// of a production rate, overflow-selling, or moving a resource into
// another business's stock. Faking a revenuePerDay here to make the
// business "feel" profitable would misrepresent that design, so every
// role below is 0 -- hiring Farmers costs money and (honestly) does
// nothing to this business's own accrued cash yet, until Settle() (or a
// per-business replacement) grows real production/transfer logic.
// GrainResource() is the forward-looking data hook that logic would hang
// off of.
public class RustvaleFarmModule extends BizModule {

  public func Def() -> BizDef {
    // Scalar/Vector4 fields assigned BEFORE any array-of-struct field --
    // see SeventhHell.reds's Def() comment for why.
    let def: BizDef;
    def.id = n"rustvale_farm";
    def.displayName = "Rustvale Farm";
    def.purchasePrice = 6000;
    def.terminalPosition = new Vector4(0.0, 0.0, 0.0, 1.0);
    def.restockCostPer10Percent = 0;
    def.stockDecayPerDayPerActiveRole = 0;
    def.prereqs = [this.NoPrereq()];
    def.roles = [this.GetRole(n"farmer1"), this.GetRole(n"farmer2"), this.GetRole(n"farmer3"), this.GetRole(n"farmer4")];
    def.inputs = [];
    def.outputs = [this.GrainResource()];
    return def;
  }

  // maxQuantity matches the demo's own Farm-side Grain buffer;
  // quantityPerDay is the demo's fully-staffed total (4 Farmers x
  // 8/day) -- not yet tied to actual hired headcount, since nothing
  // consumes BizDef.outputs yet (see class comment above).
  private func GrainResource() -> ref<Resource> {
    return SimpleResource.Create(n"grain", "Grain", 32, 60);
  }

  // No real purchase gate for this business yet -- a trivially-satisfied
  // Level prereq (every player is at least level 1) instead of an empty
  // `def.prereqs = []` literal, since every other BizDef in this codebase
  // (7th Hell) always populates prereqs with at least one real element,
  // and array<Struct> is already known to be a fragile, different
  // compiler path in this redscript build (see AGENTS.md) -- an empty
  // struct-array literal is untested territory this sidesteps entirely.
  private func NoPrereq() -> BizPrereq {
    let p: BizPrereq;
    p.kind = BizPrereqKind.Level;
    p.requiredLevel = 1;
    return p;
  }

  // 4 interchangeable Farmer slots -- it doesn't matter which Farmer is
  // hired, only how many, same "identical headcount, not distinct
  // roles" pattern as Northside Warehouse's Drivers.
  public func GetRole(id: CName) -> BizRoleDef {
    if Equals(id, n"farmer1") {
      return MakeBizRole(n"farmer1", r"base/characters/entities/service/service__municipial_ma.ent", 0.0, 0.0, 0.0, 0.0, 60, 0);
    }
    if Equals(id, n"farmer2") {
      return MakeBizRole(n"farmer2", r"base/characters/entities/gang/gang__cyberpunk_ma.ent", 0.0, 0.0, 0.0, 0.0, 60, 0);
    }
    if Equals(id, n"farmer3") {
      return MakeBizRole(n"farmer3", r"base/characters/entities/citizen/citizen__rich_ma.ent", 0.0, 0.0, 0.0, 0.0, 60, 0);
    }
    return MakeBizRole(n"farmer4", r"base/quest/main_quests/prologue/q004/lizzies_club/characters/lizzies_customer_female_middle_bd.ent", 0.0, 0.0, 0.0, 0.0, 60, 0);
  }

}

// Self-registration, same pattern as SeventhHell.reds -- base/ never
// names this module, so it's responsible for announcing itself.
@wrapMethod(ScriptedPuppet)
protected cb func OnGameAttached() -> Void {
  wrappedMethod();
  if this.IsPlayer() {
    CorpoBizRegistry.Register(this.GetGame(), new RustvaleFarmModule());
  }
}
