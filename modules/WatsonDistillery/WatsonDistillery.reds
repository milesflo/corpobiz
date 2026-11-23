module CorpoBiz.WatsonDistillery
import CorpoBiz.*

// Watson Distillery -- middle stage of the Farm -> Watson -> Warehouse ->
// 7th Hell chain prototyped in a browser-demo mockup. Consumes Grain,
// produces Alcohol. No real-world site scouted yet -- terminalPosition
// and every role's position below are placeholders (see Def() and
// GetRole()).
//
// Grain is this business's BizDef.inputs[0] -- CorpoBiz.PrimaryResource
// picks it up automatically, so CorpoBiz.Settle's existing fill-fraction
// revenue scaling and per-active-role stock decay both apply to it with
// no engine changes. stockDecayPerDayPerActiveRole (20) is each hired
// Distiller's Grain draw from the demo's final design -- Settle already
// multiplies that by hired headcount, which happens to line up well with
// the demo's "consumption scales with employees" lesson even though
// Settle calls it decay, not consumption.
//
// What's a simplification, not a 1:1 port: the demo had Distillers
// produce Alcohol at a rate gated by actual Grain on hand (1:1 with
// consumption) and turn a profit by auto-selling whatever overflowed
// Watson's own buffer once it filled, rather than drawing a flat
// per-role revenue. Settle has no notion of production rate or
// overflow-selling, so Distiller.revenuePerDay below is a flat number,
// gated only by Grain's current fill fraction -- close in spirit
// (no Grain, no revenue) but not the same mechanism. AlcoholResource()
// is the forward-looking data hook for when Settle (or a replacement)
// grows real production/transfer logic.
public class WatsonDistilleryModule extends BizModule {

  public func Def() -> BizDef {
    // Scalar/Vector4 fields assigned BEFORE any array-of-struct field --
    // see SeventhHell.reds's Def() comment for why.
    let def: BizDef;
    def.id = n"watson_distillery";
    def.displayName = "Watson Distillery";
    def.purchasePrice = 14000;
    def.terminalPosition = new Vector4(0.0, 0.0, 0.0, 1.0);
    def.restockCostPer10Percent = 70;
    def.stockDecayPerDayPerActiveRole = 20;
    def.prereqs = [this.NoPrereq()];
    def.roles = [this.GetRole(n"distiller1"), this.GetRole(n"distiller2"), this.GetRole(n"distiller3"), this.GetRole(n"guard")];
    def.inputs = [this.GrainResource()];
    def.outputs = [this.AlcoholResource()];
    return def;
  }

  // maxQuantity matches the demo's own Watson-side Grain buffer.
  private func GrainResource() -> ref<Resource> {
    return SimpleResource.Create(n"grain", "Grain", 60, 80);
  }

  // No real purchase gate for this business yet -- see RustvaleFarm's
  // own NoPrereq() comment for why this is a trivially-satisfied Level
  // prereq instead of an empty `def.prereqs = []` literal.
  private func NoPrereq() -> BizPrereq {
    let p: BizPrereq;
    p.kind = BizPrereqKind.Level;
    p.requiredLevel = 1;
    return p;
  }

  // quantityPerDay is the demo's fully-staffed (3 Distillers x 20/day,
  // 1:1 with Grain) total -- not yet tied to actual hired headcount or
  // actually produced anywhere, since nothing consumes BizDef.outputs
  // yet (see class comment above).
  private func AlcoholResource() -> ref<Resource> {
    return SimpleResource.Create(n"alcohol", "Alcohol", 60, 50);
  }

  // 3 interchangeable Distiller slots (same pattern as Rustvale Farm's
  // Farmers) plus one Guard for Security -- Guard's revenuePerDay is 0,
  // same as every other business's security role; it only moves the
  // 3-tier Security read elsewhere in this framework, once that's wired
  // up for this module too.
  public func GetRole(id: CName) -> BizRoleDef {
    if Equals(id, n"distiller1") {
      return MakeBizRole(n"distiller1", r"base/characters/entities/service/service__municipial_ma.ent", 0.0, 0.0, 0.0, 0.0, 500, 250);
    }
    if Equals(id, n"distiller2") {
      return MakeBizRole(n"distiller2", r"base/characters/entities/citizen/citizen__rich_ma.ent", 0.0, 0.0, 0.0, 0.0, 500, 250);
    }
    if Equals(id, n"distiller3") {
      return MakeBizRole(n"distiller3", r"base/quest/main_quests/prologue/q004/lizzies_club/characters/lizzies_customer_female_middle_bd.ent", 0.0, 0.0, 0.0, 0.0, 500, 250);
    }
    return MakeBizRole(n"guard", r"base/characters/entities/gang/gang__cyberpunk_ma.ent", 0.0, 0.0, 0.0, 0.0, 300, 0);
  }

}

// Self-registration, same pattern as SeventhHell.reds -- base/ never
// names this module, so it's responsible for announcing itself.
@wrapMethod(ScriptedPuppet)
protected cb func OnGameAttached() -> Void {
  wrappedMethod();
  if this.IsPlayer() {
    CorpoBizRegistry.Register(this.GetGame(), new WatsonDistilleryModule());
  }
}
