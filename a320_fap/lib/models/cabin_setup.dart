// Cabin configuration data held by the CAM (Cabin Assignment Module):
// seat layouts with their passenger classes, boarding music channels and
// the areas whose loudspeaker levels can be adjusted.

enum CabinClass {
  first('FIRST CLASS', 'F/C'),
  business('BUSINESS CLASS', 'B/C'),
  tourist('TOURIST CLASS', 'T/C');

  const CabinClass(this.label, this.short);
  final String label;
  final String short;
}

/// One CAM layout: seat rows and the first row of each class.
class CabinLayout {
  const CabinLayout({
    required this.id,
    required this.rows,
    required this.classes,
    required this.defaultStarts,
  });

  final int id;
  final int rows;
  final List<CabinClass> classes;

  /// First seat row of each class, same order as [classes]; starts at 1.
  final List<int> defaultStarts;

  String get description =>
      '${classes.length} ${classes.length == 1 ? 'CLASS' : 'CLASSES'}, '
      '$rows SEATROWS';
}

const cabinLayouts = <CabinLayout>[
  CabinLayout(
    id: 1,
    rows: 30,
    classes: [CabinClass.tourist],
    defaultStarts: [1],
  ),
  CabinLayout(
    id: 2,
    rows: 30,
    classes: [CabinClass.business, CabinClass.tourist],
    defaultStarts: [1, 5],
  ),
  CabinLayout(
    id: 3,
    rows: 36,
    classes: [CabinClass.first, CabinClass.business, CabinClass.tourist],
    defaultStarts: [1, 4, 11],
  ),
];

CabinLayout layoutById(int id) =>
    cabinLayouts.firstWhere((l) => l.id == id, orElse: () => cabinLayouts.last);

/// Seat letters of an A320 single-aisle row (3 + 3).
const seatLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

enum BgmChannel {
  blues('Blues'),
  classic('Classic'),
  country('Country'),
  jazz('Jazz');

  const BgmChannel(this.label);
  final String label;
}

/// Areas whose announcement / chime loudspeaker level can be adjusted.
enum LevelGroup {
  cabinZones('CABIN ZONES'),
  attendantAreas('ATTENDANT AREAS'),
  lavatories('LAVATORIES');

  const LevelGroup(this.label);
  final String label;
}

class LevelSetting {
  const LevelSetting({this.announce = 0, this.chime = 0});
  final int announce; // dB
  final int chime; // dB

  LevelSetting copyWith({int? announce, int? chime}) => LevelSetting(
    announce: announce ?? this.announce,
    chime: chime ?? this.chime,
  );
}

class SetupLimits {
  SetupLimits._();
  static const minDb = -6;
  static const maxDb = 6;

  /// Access codes of the protected pages (CIDS defaults).
  static const programmingCode = '318';
  static const softwareCode = '813';
}
