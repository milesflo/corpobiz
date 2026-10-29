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
public abstract class BizModule {

  public func Def() -> BizDef;

  public func GetRole(id: CName) -> BizRoleDef;

  public func RoleVariantCount(id: CName) -> Int32;

  public func RoleVariantTemplatePath(id: CName, variant: Int32) -> ResRef;

  public func RoleVariantName(id: CName, variant: Int32) -> String;
}
