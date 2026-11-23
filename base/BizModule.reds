module CorpoBiz

// The CorpoBiz module contract. Every business is a class extending
// BizModule, registered as an instance in Registry.reds's
// CorpoBizRegistry.All(). The generic engine (CorpoBiz.reds,
// StaffSpawner.reds, HostileCleanup.reds, TerminalUI.reds) only ever talks
// to businesses through this interface -- it never references a specific
// business by name. Role-level data (position, cost, revenue) lives on
// BizDef/BizRoleDef (pure data, returned by Def()); only the "look variant"
// catalog is resolved through virtual methods here, since embedding every
// variant's template path directly on BizRoleDef would bloat every role
// with data only some businesses use.
//
// RoleVariantCount/TemplatePath/Name have default implementations returning
// four generic vanilla NPC templates -- override them only if a business
// needs its own character appearance catalog.
public abstract class BizModule {

  public func Def() -> BizDef;

  public func GetRole(id: CName) -> BizRoleDef;

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
}

// Shared helpers for BizModule implementations -- avoids copy-pasting
// role construction and yaw-to-quaternion conversion into every module.
public static func MakeBizRole(id: CName, templatePath: ResRef, x: Float, y: Float, z: Float, yaw: Float, hireCost: Int32, revenuePerDay: Int32) -> BizRoleDef {
  let role: BizRoleDef;
  role.id = id;
  role.templatePath = templatePath;
  role.position = new Vector4(x, y, z, 1.0);
  role.orientation = YawToQuat(yaw);
  role.hireCost = hireCost;
  role.revenuePerDay = revenuePerDay;
  return role;
}

public static func YawToQuat(yaw: Float) -> Quaternion {
  let angles: EulerAngles;
  angles.Yaw = yaw;
  return angles.ToQuat();
}
