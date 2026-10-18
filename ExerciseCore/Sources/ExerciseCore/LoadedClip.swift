import Foundation

/// The clip on screen (#176, step 5a): which file plays, where it came from, which stored set it is, when its
/// first frame was taken, and what a trim replaced so it can be undone. One value, so a new clip replaces all of
/// it in one assignment and none of the old clip's fields can linger.
public struct LoadedClip<Origin: Sendable> {
  /// The clip as loaded, or as last trimmed in place.
  public var url: URL
  /// The trimmed file, once this clip was trimmed; it is what plays and what the next trim cuts.
  public var trimmedURL: URL?
  public var origin: Origin
  /// The stored set, once there is one: a clip loaded from a file gets its id at the first save.
  public var entryID: String?
  public var recordedAt: Date?
  /// Wall-clock time of the first frame (`RecentEntry.clipStartedAt`), what lines the playhead up with heart rate
  /// (051); nil for imported clips. A trim moves it, its undo moves it back.
  public var startedAt: Date?
  public var untrimmed: Untrimmed?
  /// The Photos asset the trimmed clip replaced (#90), so the undo can put the original back into Photos.
  public var replacedOriginalID: String?

  /// What a trim replaced: the untrimmed clip and its analysis.
  public struct Untrimmed {
    public let url: URL
    public let pipeline: AnalysisPipeline
    public let frames: [FrameRecord]
    public let origin: Origin
    public let startedAt: Date?
    /// The set whose folder holds `url` as its stashed original (an in-app set's own clip, #199); nil otherwise.
    public var stashedFor: String?

    public init(
      url: URL, pipeline: AnalysisPipeline, frames: [FrameRecord], origin: Origin, startedAt: Date?,
      stashedFor: String? = nil
    ) {
      self.url = url
      self.pipeline = pipeline
      self.frames = frames
      self.origin = origin
      self.startedAt = startedAt
      self.stashedFor = stashedFor
    }
  }

  public init(url: URL, origin: Origin, entryID: String?, recordedAt: Date?, startedAt: Date?) {
    self.url = url
    self.origin = origin
    self.entryID = entryID
    self.recordedAt = recordedAt
    self.startedAt = startedAt
  }

  /// The file that plays: the trimmed one once there is one.
  public var playing: URL { trimmedURL ?? url }

  /// The trim wrote `clip`, whose first frame is `start` seconds into the clip it cut. A cut gap between runs
  /// (#83) breaks the clock past it, so a joined clip gets no first-frame time, as a paused recording does.
  public mutating func trimmed(to clip: URL, start: Double, joined: Bool) {
    trimmedURL = clip
    startedAt = joined ? nil : startedAt?.addingTimeInterval(start)
  }

  /// Puts the untrimmed clip back: its file, origin and first-frame time. Returns the trimmed file it dropped.
  public mutating func undo(to before: Untrimmed) -> URL? {
    let dropped = trimmedURL
    untrimmed = nil
    trimmedURL = nil
    url = before.url
    origin = before.origin
    startedAt = before.startedAt
    return dropped
  }
}
