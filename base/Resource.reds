module CorpoBiz

// Base contract for any tradeable/consumable good a business works with
// (e.g. 7th Hell's "Alcohol"). Money is deliberately NOT a Resource -- it's
// earned/collected and tracked separately via CorpoBizState's accrued-cash
// Facts, not produced/consumed through a business's inputs/outputs the way
// goods are.
//
// A business's BizDef.inputs/outputs are Resource instances: Id()/
// DisplayName() identify the resource, and `quantityPerDay` is the
// consumption/production rate -- how much of that resource one in-game day
// consumes (for an input) or yields (for an output). Per in-game day,
// matching revenuePerDay/stockDecayPerDayPerActiveRole elsewhere in the
// framework, rather than some other "tick": CorpoBiz.Settle accrues
// continuously from elapsed in-game time (fractional days), not discrete
// steps, and the only thing resembling a "tick" (StaffSpawner's proximity
// poll) runs on a fixed *real-world* interval unrelated to game-economy
// pacing, so it isn't a meaningful rate unit here.
//
// That's what makes a business "turning any number of resources into any
// number of other resources" just a matter of how many Resource entries
// are in inputs/outputs, with no limit on count or mix of resource types.
// A business's actual, persisted amount currently on hand is tracked
// separately via CorpoBizState.GetStock/SetStock -- this class only
// describes the resource's identity and its rate, not current stock level.
public abstract class Resource {
  public let quantityPerDay: Int32;

  public func Id() -> CName;
  public func DisplayName() -> String;
}

// A generic resource needing no special behavior beyond a name and a
// consumption/production rate -- covers most cases. Extend Resource
// directly instead if a specific resource needs its own logic (e.g.
// something that decays differently, or enforces its own valid quantity
// range).
public class SimpleResource extends Resource {
  private let m_id: CName;
  private let m_displayName: String;

  public func Id() -> CName {
    return this.m_id;
  }

  public func DisplayName() -> String {
    return this.m_displayName;
  }

  public static func Create(id: CName, displayName: String, quantityPerDay: Int32) -> ref<SimpleResource> {
    let r = new SimpleResource();
    r.m_id = id;
    r.m_displayName = displayName;
    r.quantityPerDay = quantityPerDay;
    return r;
  }
}
