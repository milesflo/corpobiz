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
    let def: BizDef;
    def.id = n"rustvale_farm";
    def.displayName = "Rustvale Farm";
    def.purchasePrice = 6000;
    def.prereqs = [];
    def.terminalPosition = new Vector4(0.0, 0.0, 0.0, 1.0);
    def.roles = [this.GetRole(n"farmer1"), this.GetRole(n"farmer2"), this.GetRole(n"farmer3"), this.GetRole(n"farmer4")];
    def.inputs = [];
    def.outputs = [this.GrainResource()];
    def.restockCostPer10Percent = 0;
    def.stockDecayPerDayPerActiveRole = 0;
    return def;
  }

  // maxQuantity matches the demo's own Farm-side Grain buffer;
  // quantityPerDay is the demo's fully-staffed total (4 Farmers x
  // 8/day) -- not yet tied to actual hired headcount, since nothing
  // consumes BizDef.outputs yet (see class comment above).
  private func GrainResource() -> ref<Resource> {
    return SimpleResource.Create(n"grain", "Grain", 32, 60);
  }

  // 4 interchangeable Farmer slots -- it doesn't matter which Farmer is
  // hired, only how many, same "identical headcount, not distinct
  // roles" pattern as Northside Warehouse's Drivers.
  public func GetRole(id: CName) -> BizRoleDef {
    if Equals(id, n"farmer1") {
      return this.MakeRole(n"farmer1", r"base/characters/entities/service/service__municipial_ma.ent", 0.0, 0.0, 0.0, 0.0, 60, 0);
    }
    if Equals(id, n"farmer2") {
      return this.MakeRole(n"farmer2", r"base/characters/entities/gang/gang__cyberpunk_ma.ent", 0.0, 0.0, 0.0, 0.0, 60, 0);
    }
    if Equals(id, n"farmer3") {
      return this.MakeRole(n"farmer3", r"base/characters/entities/citizen/citizen__rich_ma.ent", 0.0, 0.0, 0.0, 0.0, 60, 0);
    }
    return this.MakeRole(n"farmer4", r"base/quest/main_quests/prologue/q004/lizzies_club/characters/lizzies_customer_female_middle_bd.ent", 0.0, 0.0, 0.0, 0.0, 60, 0);
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
    CorpoBizRegistry.Register(this.GetGame(), new RustvaleFarmModule());
  }
}
