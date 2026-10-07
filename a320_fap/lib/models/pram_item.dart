/// A pre-recorded announcement (PRAM) entry.
///
/// Each item is a recorded PA announcement in `assets/pram/<id>.mp3`
/// (regenerate with `python tool/gen_pram.py` after editing a script).
class PramItem {
  const PramItem({
    required this.id,
    required this.code,
    required this.title,
    required this.script,
  });

  final String id;
  final String code;
  final String title;
  final String script;
}

/// Announcements in the order of a flight, from boarding to arrival.
const pramLibrary = <PramItem>[
  PramItem(
    id: 'welcome',
    code: '010',
    title: 'WELCOME ABOARD',
    script:
        'Good day ladies and gentlemen, and welcome aboard this Airbus '
        'A320. Please place your carry-on baggage in the overhead bins or '
        'under the seat in front of you, and take your seat as quickly as '
        'possible to allow other passengers to board. Thank you.',
  ),
  PramItem(
    id: 'safety',
    code: '020',
    title: 'SAFETY DEMONSTRATION',
    script:
        'Ladies and gentlemen, please direct your attention to the cabin '
        'crew for the safety demonstration. To fasten your seat belt, insert '
        'the metal tip into the buckle and pull the strap tight. To release, '
        'lift the top of the buckle. There are eight emergency exits on this '
        'aircraft: two doors at the front, four window exits over the wings, '
        'and two doors at the rear. Please take a moment to locate the exit '
        'nearest to you, keeping in mind it may be behind you. In the event '
        'of an emergency, floor path lighting will guide you to the exits. '
        'If cabin pressure is lost, oxygen masks will drop from the panel '
        'above you. Pull the mask towards you, place it over your nose and '
        'mouth, and breathe normally. Secure your own mask before assisting '
        'others. Your life vest is located under your seat. Thank you for '
        'your attention.',
  ),
  PramItem(
    id: 'nosmoking',
    code: '030',
    title: 'NO SMOKING',
    script:
        'Ladies and gentlemen, this is a non-smoking flight. Smoking, '
        'including electronic cigarettes, is not permitted anywhere on '
        'board, including the lavatories. The lavatories are fitted with '
        'smoke detectors. Thank you for your cooperation.',
  ),
  PramItem(
    id: 'devices',
    code: '040',
    title: 'ELECTRONIC DEVICES',
    script:
        'Ladies and gentlemen, all portable electronic devices must now be '
        'switched to flight mode. Laptops and other large devices must be '
        'stowed in the overhead bins or under the seat in front of you for '
        'take-off and landing. Thank you.',
  ),
  PramItem(
    id: 'takeoff',
    code: '050',
    title: 'PREPARE FOR TAKE-OFF',
    script:
        'Ladies and gentlemen, we are now ready for departure. Please make '
        'sure your seat belt is fastened, your seat back is upright, your '
        'tray table is stowed, your window shade is open, and your armrests '
        'are down. Cabin crew, please be seated for take-off.',
  ),
  PramItem(
    id: 'seatbelt',
    code: '060',
    title: 'FASTEN SEAT BELTS',
    script:
        'Ladies and gentlemen, the captain has switched on the fasten '
        'seat belt sign. Please return to your seats and fasten your seat '
        'belts. The lavatories should not be used at this time. Thank you.',
  ),
  PramItem(
    id: 'seatbeltoff',
    code: '070',
    title: 'SEAT BELT SIGN OFF',
    script:
        'Ladies and gentlemen, the captain has switched off the fasten seat '
        'belt sign. You may now move about the cabin. However, while you are '
        'seated, we recommend that you keep your seat belt fastened at all '
        'times, as we may experience unexpected turbulence. Thank you.',
  ),
  PramItem(
    id: 'turbulence',
    code: '080',
    title: 'TURBULENCE ALERT',
    script:
        'Ladies and gentlemen, we are experiencing an area of '
        'turbulence. Please return to your seats immediately and keep your '
        'seat belts securely fastened. Cabin service has been suspended. '
        'Thank you.',
  ),
  PramItem(
    id: 'medical',
    code: '090',
    title: 'DOCTOR ON BOARD',
    script:
        'Ladies and gentlemen, if there is a doctor, a nurse, or any medical '
        'professional on board, please identify yourself to a member of the '
        'cabin crew by pressing your call button. Thank you.',
  ),
  PramItem(
    id: 'delay',
    code: '100',
    title: 'GROUND DELAY',
    script:
        'Ladies and gentlemen, we are currently waiting for clearance from '
        'air traffic control, and we expect a short delay before departure. '
        'Please remain seated with your seat belt fastened. We apologize for '
        'the inconvenience, and we will keep you informed. Thank you for '
        'your patience.',
  ),
  PramItem(
    id: 'descent',
    code: '110',
    title: 'DESCENT PREPARATION',
    script:
        'Ladies and gentlemen, we have started our descent. Please '
        'return to your seats, make sure your seat belts are fastened, your '
        'seat backs are upright, your tray tables are stowed, and your window '
        'shades are open. Electronic devices must be in flight mode. '
        'Cabin crew, prepare the cabin for landing.',
  ),
  PramItem(
    id: 'landing',
    code: '120',
    title: 'FINAL APPROACH',
    script:
        'Ladies and gentlemen, we are now on our final approach. Please make '
        'sure your seat belt is securely fastened and all your belongings '
        'are stowed. Cabin crew, please be seated for landing.',
  ),
  PramItem(
    id: 'arrival',
    code: '130',
    title: 'ARRIVAL / DISEMBARK',
    script:
        'Ladies and gentlemen, welcome to your destination. Please remain '
        'seated with your seat belts fastened until the aircraft has come to '
        'a complete stop and the seat belt sign has been switched off. Use '
        'caution when opening the overhead bins. Thank you for flying with '
        'us.',
  ),
];
