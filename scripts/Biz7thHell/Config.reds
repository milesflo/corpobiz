module Biz7thHell

public struct RoleDef {
  let id: CName;
  let templatePath: ResRef;
  let position: Vector4;
  let orientation: Quaternion;
  let hireCost: Int32;
  let revenuePerDay: Int32;
}

public class Config {

  public static func PurchasePrice() -> Int32 {
    return 15000;
  }

  public static func RestockCostPer10Percent() -> Int32 {
    return 150;
  }

  public static func StockDecayPerDayPerActiveRole() -> Int32 {
    return 8;
  }

  public static func TerminalPosition() -> Vector4 {
    return new Vector4(-1939.11, -49.75, -0.45, 1.0);
  }

  // array<CName> works fine (native element type); array<RoleDef> does not
  // compile with this redscript build ("has no members" on PushBack for any
  // user-defined struct), so roles are looked up individually by id instead
  // of being collected into an array<RoleDef>.
  //
  // No "bartender" role: the venue's own vanilla bartender NPC is already
  // present and already serving drinks, so hiring/spawning one would be
  // redundant. Cash is collected directly from the terminal's Stock page
  // instead of via an in-person bartender interaction.
  public static func RoleIds() -> array<CName> {
    return [n"bouncer", n"dj", n"dancer"];
  }

  public static func GetRole(id: CName) -> RoleDef {
    if Equals(id, n"bouncer") {
      return Config.MakeRole(n"bouncer", r"base/characters/entities/gang/gang__cyberpunk_ma.ent", -1941.50, -57.13, 7.45, -74.15, 400, 150);
    }
    if Equals(id, n"dj") {
      return Config.MakeRole(n"dj", r"base/characters/entities/citizen/citizen__rich_ma.ent", -1912.52, -42.24, -0.53, 91.80, 350, 200);
    }
    return Config.MakeRole(n"dancer", r"base/quest/main_quests/prologue/q004/lizzies_club/characters/lizzies_customer_female_middle_bd.ent", -1928.49, -42.23, -0.69, 86.20, 350, 200);
  }

  // Look variants for the Staff page's "change model" action. Reuses the
  // same four templates already confirmed to spawn correctly for the four
  // roles, rather than guessing at unverified vanilla entity paths.
  public static func RoleVariantCount(id: CName) -> Int32 {
    return 4;
  }

  public static func RoleVariantTemplatePath(id: CName, variant: Int32) -> ResRef {
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

  public static func RoleVariantName(id: CName, variant: Int32) -> String {
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

  private static func MakeRole(id: CName, templatePath: ResRef, x: Float, y: Float, z: Float, yaw: Float, hireCost: Int32, revenuePerDay: Int32) -> RoleDef {
    let role: RoleDef;
    role.id = id;
    role.templatePath = templatePath;
    role.position = new Vector4(x, y, z, 1.0);
    role.orientation = YawToQuat(yaw);
    role.hireCost = hireCost;
    role.revenuePerDay = revenuePerDay;
    return role;
  }
}

public static func YawToQuat(yaw: Float) -> Quaternion {
  let angles: EulerAngles;
  angles.Yaw = yaw;
  return angles.ToQuat();
}
