// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

//  The drawn legs of a split squat keep their names (#131). The model trades the legs' labels back and forth for
//  under a second, at full confidence, so the skeleton scissors on screen. The feet do not move during a split
//  squat, and while standing the two legs are unambiguous (Igor, 2026-09-29: "we know the legs from when we're
//  standing ... You can latch a leg instead"). So each standing frame latches where each ankle is; every other
//  frame's legs are swapped back when their ankles sit on the other's spot, and an ankle away from its spot is
//  drawn at it. Bulgarian only: the split-squat fixtures' legs are clean and the latch added jumps there.
//  Drawing only: the analyzers and the stored track keep the model's poses as they came.

import Foundation

public final class LegLatch {
  /// Ankles closer than this (normalized) while standing are too close to tell apart, and latch nothing.
  public static let minApart: Float = 0.04
  /// An ankle this far from its latched spot is drawn at it.
  public static let holdDistance: Float = 0.05

  private var anchor: (left: PosePoint, right: PosePoint)?

  public init() {}

  public func reset() { anchor = nil }

  /// What was done to the frame, for the tuning report.
  public enum Fix: Equatable { case none, latched, swapped, held }

  public func process(_ pose: Pose, standing: Bool) -> (pose: Pose, fix: Fix) {
    let la = CocoKeypoint.leftAnkle.rawValue, ra = CocoKeypoint.rightAnkle.rawValue
    guard pose.conf.count > max(la, ra), pose.xyn.count > max(la, ra) else { return (pose, .none) }
    let seen = { (i: Int) in pose.conf[i] > BodySkeleton.visibleThreshold }
    let both = seen(la) && seen(ra)
    let apart = both && Self.distance(pose.xyn[la], pose.xyn[ra]) > Self.minApart
    guard let anchor else {
      if standing, apart { anchor = (pose.xyn[la], pose.xyn[ra]) }
      return (pose, anchor == nil ? .none : .latched)
    }

    var out = pose
    var fix = Fix.none
    // Swapped when the ankles sit on each other's spots: the swap moves them less than half as far as keeping.
    // Tested before re-latching, so a standing frame with traded names cannot latch them.
    if both {
      let keep = Self.distance(pose.xyn[la], anchor.left) + Self.distance(pose.xyn[ra], anchor.right)
      let swap = Self.distance(pose.xyn[la], anchor.right) + Self.distance(pose.xyn[ra], anchor.left)
      if swap < keep * 0.5 {
        out = Self.swappingLegs(pose)
        fix = .swapped
      }
    }
    if standing, apart {
      self.anchor = (out.xyn[la], out.xyn[ra])
      return (out, fix == .none ? .latched : fix)
    }
    // An ankle away from its own spot is drawn there: the feet stay put between standing frames. Holding only an
    // ankle that sat on the other foot left twice the jumps on the Bulgarian fixtures (the 2026-09-29 entry).
    for (i, own) in [(la, anchor.left), (ra, anchor.right)]
    where out.conf[i] > BodySkeleton.visibleThreshold && Self.distance(out.xyn[i], own) > Self.holdDistance {
      out = Self.moving(out, keypoint: i, to: own)
      if fix == .none { fix = .held }
    }
    return (out, fix)
  }

  static func distance(_ a: PosePoint, _ b: PosePoint) -> Float { hypot(a.x - b.x, a.y - b.y) }

  /// The leg's names traded back: knee and ankle (the hips sit together from the side and keep theirs).
  static func swappingLegs(_ pose: Pose) -> Pose {
    var xyn = pose.xyn, xy = pose.xy, conf = pose.conf
    for (l, r) in [(CocoKeypoint.leftKnee, CocoKeypoint.rightKnee), (.leftAnkle, .rightAnkle)] {
      xyn.swapAt(l.rawValue, r.rawValue)
      if xy.count > max(l.rawValue, r.rawValue) { xy.swapAt(l.rawValue, r.rawValue) }
      conf.swapAt(l.rawValue, r.rawValue)
    }
    return Pose(xyn: xyn, xy: xy, conf: conf)
  }

  static func moving(_ pose: Pose, keypoint i: Int, to point: PosePoint) -> Pose {
    var xyn = pose.xyn, xy = pose.xy
    // Pixels follow the normalized move by the keypoint's own scale.
    if xy.count > i, pose.xyn[i].x > 0, pose.xyn[i].y > 0 {
      xy[i] = PosePoint(x: point.x * pose.xy[i].x / pose.xyn[i].x, y: point.y * pose.xy[i].y / pose.xyn[i].y)
    }
    xyn[i] = point
    return Pose(xyn: xyn, xy: xy, conf: pose.conf)
  }
}
