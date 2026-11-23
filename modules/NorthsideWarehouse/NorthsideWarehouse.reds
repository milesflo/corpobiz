module CorpoBiz.NorthsideWarehouse
import CorpoBiz.*

// Northside Warehouse -- last stage of the Farm -> Watson -> Warehouse ->
// 7th Hell chain prototyped in a browser-demo mockup, buffering both
// Grain (Farm -> Watson) and Alcohol (Watson -> 7th Hell) rather than
// either leg connecting straight through. No real-world site scouted
// yet -- terminalPosition and every role's position below are
// placeholders (see Def() and GetRole()).
//
// This is the one business of the three where the demo's final design
// and CorpoBiz.Settle's existing flat-revenue model actually line up
// with no simplification: Drivers ended up as a plain handling-fee
// revenue role (no capacity/throughput mechanic left -- an earlier demo
// iteration had Drivers gate connection throughput, but that cap was
// deliberately removed), same shape as every other business's Guard,
// just nonzero. def.inputs is empty on purpose -- the actual
// Farm->Warehouse->Watson and Watson->Warehouse->7th Hell resource
// transfers (what the demo's `connections` object modeled) aren't
// implemented in Settle yet, so this module earns revenue purely from
// hired staff, with no stock mechanic active. GrainResource()/
// AlcoholResource() on outputs below are the forward-looking data hooks
// for when that transfer logic exists.
public class NorthsideWarehouseModule extends BizModule {

  public func Def() -> BizDef {
    // Scalar/Vector4 fields assigned BEFORE any array-of-struct field --
    // see SeventhHell.reds's Def() comment for why.
    let def: BizDef;
    def.id = n"northside_warehouse";
    def.displayName = "Northside Warehouse";
    def.purchasePrice = 10000;
    def.terminalPosition = new Vector4(0.0, 0.0, 0.0, 1.0);
    def.restockCostPer10Percent = 0;
    def.stockDecayPerDayPerActiveRole = 0;
    def.prereqs = [this.NoPrereq()];
    def.roles = [this.GetRole(n"driver1"), this.GetRole(n"driver2"), this.GetRole(n"driver3"), this.GetRole(n"guard")];
    def.inputs = [];
    def.outputs = [this.GrainResource(), this.AlcoholResource()];
    return def;
  }

  // Buffer sizes match the demo's own Warehouse-side stocks. Not
  // actually filled/drained by anything yet -- see class comment above.
  private func GrainResource() -> ref<Resource> {
    return SimpleResource.Create(n"grain", "Grain", 0, 60);
  }

  private func AlcoholResource() -> ref<Resource> {
    return SimpleResource.Create(n"alcohol", "Alcohol", 0, 150);
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

  // 3 interchangeable Driver slots (same pattern as Rustvale Farm's
  // Farmers) plus one Guard for Security. Unlike Farm's Farmers or
  // Watson's Distillers, Drivers really are a flat revenue role in the
  // demo's final design -- $90/day each, ported directly, no caveat.
  public func GetRole(id: CName) -> BizRoleDef {
    if Equals(id, n"driver1") {
      return this.MakeRole(n"driver1", r"base/characters/entities/service/service__municipial_ma.ent", 0.0, 0.0, 0.0, 0.0, 200, 90);
    }
    if Equals(id, n"driver2") {
      return this.MakeRole(n"driver2", r"base/characters/entities/citizen/citizen__rich_ma.ent", 0.0, 0.0, 0.0, 0.0, 200, 90);
    }
    if Equals(id, n"driver3") {
      return this.MakeRole(n"driver3", r"base/quest/main_quests/prologue/q004/lizzies_club/characters/lizzies_customer_female_middle_bd.ent", 0.0, 0.0, 0.0, 0.0, 200, 90);
    }
    return this.MakeRole(n"guard", r"base/characters/entities/gang/gang__cyberpunk_ma.ent", 0.0, 0.0, 0.0, 0.0, 300, 0);
  }

  // Same 4-variant catalog 7th Hell uses -- confirmed to spawn correctly,
  // and look doesn't matter yet for a business with no real site.
  public func RoleVariantCount(id: CName) -> Int32 {
    return 4;
  }

  public func RoleVariantTemplatePath(id: CName, variant: Int32) -> ResRef {
    if variant == 0 {
      return r"base/characters/entities/service/service__municipial_ma.ent";
    }
    if variant == 1 {
      return r"base/characters/entities/gang/gang__cyberpunk_ma.ent";
    }
    if variant == 2 {
      return r"base/characters/entities/citizen/citizen__rich_ma.ent";
    }
    return r"base/quest/main_quests/prologue/q004/lizzies_club/characters/lizzies_customer_female_middle_bd.ent";
  }

  public func RoleVariantName(id: CName, variant: Int32) -> String {
    if variant == 0 {
      return "Style 1";
    }
    if variant == 1 {
      return "Style 2";
    }
    if variant == 2 {
      return "Style 3";
    }
    return "Style 4";
  }

  private func MakeRole(id: CName, templatePath: ResRef, x: Float, y: Float, z: Float, yaw: Float, hireCost: Int32, revenuePerDay: Int32) -> BizRoleDef {
    let role: BizRoleDef;
    role.id = id;
    role.templatePath = templatePath;
    role.position = new Vector4(x, y, z, 1.0);
    role.orientation = this.YawToQuat(yaw);
    role.hireCost = hireCost;
    role.revenuePerDay = revenuePerDay;
    return role;
  }

  private func YawToQuat(yaw: Float) -> Quaternion {
    let angles: EulerAngles;
    angles.Yaw = yaw;
    return angles.ToQuat();
  }
}

// Self-registration, same pattern as SeventhHell.reds -- base/ never
// names this module, so it's responsible for announcing itself.
@wrapMethod(ScriptedPuppet)
protected cb func OnGameAttached() -> Void {
  wrappedMethod();
  if this.IsPlayer() {
    CorpoBizRegistry.Register(this.GetGame(), new NorthsideWarehouseModule());
  }
}
