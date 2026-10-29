module CorpoBiz.SeventhHell
import CorpoBiz.*

// The first business installed on the CorpoBiz framework: the nightclub
// 7th Hell, unlocked after the side gig "An Inconvenient Killer".
public class SeventhHellModule extends BizModule {

  public func Def() -> BizDef {
    let def: BizDef;
    def.id = n"seventh_hell";
    def.displayName = "7th Hell";
    def.purchasePrice = 15000;
    def.prereqs = [this.GigPrereq()];
    def.terminalPosition = new Vector4(-1939.11, -49.75, -0.45, 1.0);
    def.roles = [this.GetRole(n"bouncer"), this.GetRole(n"dj"), this.GetRole(n"dancer")];
    def.inputs = [this.AlcoholResource()];
    def.outputs = [];
    def.restockCostPer10Percent = 150;
    def.stockDecayPerDayPerActiveRole = 8;
    return def;
  }

  // The real internal fact/journal entry for "An Inconvenient Killer"'s
  // completion couldn't be reliably identified without decompiling the
  // quest resource, so this is a self-asserted flag instead of a real
  // vanilla quest fact. Set it from the console to unlock for testing:
  //   Game.GetQuestsSystem():SetFact("corpobiz_seventh_hell_gig_done", 1)
  private func GigPrereq() -> BizPrereq {
    let p: BizPrereq;
    p.kind = BizPrereqKind.Quest;
    p.questFact = n"corpobiz_seventh_hell_gig_done";
    return p;
  }

  private func AlcoholResource() -> BizResource {
    let r: BizResource;
    r.id = n"alcohol";
    r.displayName = "Alcohol";
    return r;
  }

  // array<CName> works fine (native element type); array<RoleDef>-shaped
  // things do not compile in this redscript build ("has no members" on
  // PushBack for any user-defined struct), so roles are looked up
  // individually by id rather than collected into an array and iterated
  // with methods.
  public func GetRole(id: CName) -> BizRoleDef {
    if Equals(id, n"bouncer") {
      return this.MakeRole(n"bouncer", r"base/characters/entities/gang/gang__cyberpunk_ma.ent", -1941.50, -57.13, 7.45, -74.15, 400, 150);
    }
    if Equals(id, n"dj") {
      return this.MakeRole(n"dj", r"base/characters/entities/citizen/citizen__rich_ma.ent", -1912.52, -42.24, -0.53, 91.80, 350, 200);
    }
    return this.MakeRole(n"dancer", r"base/quest/main_quests/prologue/q004/lizzies_club/characters/lizzies_customer_female_middle_bd.ent", -1928.49, -42.23, -0.69, 86.20, 350, 200);
  }

  // Look variants for the Staff page's "change model" action. Reuses
  // templates already confirmed to spawn correctly for these roles, rather
  // than guessing at unverified vanilla entity paths.
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
