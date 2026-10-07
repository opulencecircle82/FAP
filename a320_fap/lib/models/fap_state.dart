// State model for the A320 CIDS Flight Attendant Panel simulator.
//
// Behaviour follows the classic A320 CIDS FAP:
//  * Cabin light levels are BRT (100 %), DIM 1 (50 %) and DIM 2 (10 %).
//  * Doors report CLOSED/OPEN and slides ARMED/DISARMED. Opening an armed
//    door deploys its slide.
//  * Potable water tank 200 L, waste tank 170 L, lavatories A, D and E.

enum FapPage {
  // Bank 1: cabin operation pages.
  cabinStatus('CABIN STATUS', 'STATUS', 1),
  audio('AUDIO', 'AUDIO', 1),
  lights('CABIN LIGHTING', 'LIGHTS', 1),
  doors('DOORS / SLIDES', 'DOORS\nSLIDES', 1),
  temperature('CABIN TEMPERATURE', 'TEMP', 1),
  water('WATER / WASTE', 'WATER\nWASTE', 1),
  smoke('SMOKE DETECTION', 'SMOKE\nDETECT', 1),
  seat('SEAT SETTINGS', 'SEAT\nSETTING', 1),
  systemInfo('SYSTEM INFO', 'SYSTEM\nINFO', 1),
  // Bank 2: CAM programming and maintenance pages.
  cabinProg('CABIN PROGRAMMING', 'CABIN\nPROG', 2),
  layout('LAYOUT SELECTION', 'LAYOUT\nSELECT', 2),
  level('LEVEL ADJUSTMENT', 'LEVEL\nADJUST', 2),
  swLoad('SOFTWARE LOADING', 'SW\nLOAD', 2),
  fapSetup('FAP SET-UP', 'FAP\nSET-UP', 2);

  const FapPage(this.title, this.tabLabel, this.bank);
  final String title;
  final String tabLabel;

  /// Which row of the page selector the tab sits in (1 or 2).
  final int bank;

  /// Pages that ask for the CAM access code.
  bool get protected =>
      this == cabinProg || this == layout || this == level || this == swLoad;
}

enum LightLevel {
  off('OFF', 0),
  dim2('DIM 2', 10),
  dim1('DIM 1', 50),
  bright('BRT', 100);

  const LightLevel(this.label, this.percent);
  final String label;
  final int percent;
}

/// Lighting zones. The cabin zones follow the passenger classes of the
/// active CAM layout (a 1-class layout only has TOURIST CLASS).
enum LightZone {
  fwdEntry('FWD ENTRY'),
  first('FIRST CLASS'),
  business('BUSINESS CLASS'),
  tourist('TOURIST CLASS'),
  aftEntry('AFT ENTRY');

  const LightZone(this.label);
  final String label;
}

enum DoorSide { left, right }

enum DoorId {
  l1('L1', 'FWD PAX DOOR', DoorSide.left, isOverwing: false),
  r1('R1', 'FWD SERVICE DOOR', DoorSide.right, isOverwing: false),
  owL1('EMER L1', 'OVERWING EXIT', DoorSide.left, isOverwing: true),
  owR1('EMER R1', 'OVERWING EXIT', DoorSide.right, isOverwing: true),
  owL2('EMER L2', 'OVERWING EXIT', DoorSide.left, isOverwing: true),
  owR2('EMER R2', 'OVERWING EXIT', DoorSide.right, isOverwing: true),
  l2('L2', 'AFT PAX DOOR', DoorSide.left, isOverwing: false),
  r2('R2', 'AFT SERVICE DOOR', DoorSide.right, isOverwing: false);

  const DoorId(
    this.label,
    this.description,
    this.side, {
    required this.isOverwing,
  });
  final String label;
  final String description;
  final DoorSide side;

  /// Overwing exit slides are permanently armed; they have no arming lever.
  final bool isOverwing;
}

class DoorStatus {
  const DoorStatus({
    required this.closed,
    required this.armed,
    this.slideDeployed = false,
  });

  final bool closed;
  final bool armed;
  final bool slideDeployed;

  bool get isSecure => closed && armed && !slideDeployed;

  DoorStatus copyWith({bool? closed, bool? armed, bool? slideDeployed}) =>
      DoorStatus(
        closed: closed ?? this.closed,
        armed: armed ?? this.armed,
        slideDeployed: slideDeployed ?? this.slideDeployed,
      );

  Map<String, dynamic> toJson() => {
    'closed': closed,
    'armed': armed,
    'deployed': slideDeployed,
  };

  static DoorStatus fromJson(Map<String, dynamic> j) => DoorStatus(
    closed: j['closed'] as bool? ?? true,
    armed: j['armed'] as bool? ?? false,
    slideDeployed: j['deployed'] as bool? ?? false,
  );
}

enum Lavatory {
  a('LAV A', 'FWD'),
  d('LAV D', 'AFT LH'),
  e('LAV E', 'AFT RH');

  const Lavatory(this.label, this.location);
  final String label;
  final String location;
}

enum SmokeAlert {
  /// No smoke detected.
  normal,

  /// Smoke detected, alert active (red flashing + repetitive chime).
  alarm,

  /// Crew pressed SMOKE RESET: aural alert silenced, but the detector
  /// still senses smoke so the FAP keeps showing it.
  reset,
}

class LavSmokeStatus {
  const LavSmokeStatus({this.alert = SmokeAlert.normal, this.source = false});

  final SmokeAlert alert;

  /// Whether smoke is physically still present (trainer controlled).
  final bool source;

  LavSmokeStatus copyWith({SmokeAlert? alert, bool? source}) =>
      LavSmokeStatus(alert: alert ?? this.alert, source: source ?? this.source);
}

enum TempZone {
  fwd('FWD CABIN'),
  aft('AFT CABIN');

  const TempZone(this.label);
  final String label;
}

class FapConstants {
  FapConstants._();

  static const potableWaterLitres = 200;
  static const wasteTankLitres = 170;
  static const minTemp = 18.0;
  static const maxTemp = 30.0;
  static const tempStep = 0.5;

  /// The FAP can fine-adjust each zone ±2.5 °C around the cockpit setting.
  static const fapTempTrim = 2.5;
  static const waterPreselect = [25, 50, 75, 100];
  static const screenLockSeconds = 30;
}
