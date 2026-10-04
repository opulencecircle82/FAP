/// A pre-recorded announcement (PRAM) entry.
///
/// [isMusic] items play the boarding-music loop; all others are spoken
/// through the offline text-to-speech engine as a PA announcement.
class PramItem {
  const PramItem({
    required this.id,
    required this.code,
    required this.title,
    required this.script,
    this.isMusic = false,
  });

  final String id;
  final String code;
  final String title;
  final String script;
  final bool isMusic;
}

const pramLibrary = <PramItem>[
  PramItem(
    id: 'music',
    code: '01',
    title: 'BOARDING MUSIC',
    script: 'Boarding music loop.',
    isMusic: true,
  ),
  PramItem(
    id: 'welcome',
    code: '02',
    title: 'WELCOME ABOARD',
    script:
        'Good day ladies and gentlemen, and welcome aboard this Airbus '
        'A320. Please place your carry-on baggage in the overhead bins or '
        'under the seat in front of you, and take your seat as quickly as '
        'possible to allow other passengers to board. Thank you.',
  ),
  PramItem(
    id: 'safety',
    code: '03',
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
    id: 'seatbelt',
    code: '04',
    title: 'FASTEN SEAT BELTS',
    script:
        'Ladies and gentlemen, the captain has switched on the fasten '
        'seat belt sign. Please return to your seats and fasten your seat '
        'belts. The lavatories should not be used at this time. Thank you.',
  ),
  PramItem(
    id: 'turbulence',
    code: '05',
    title: 'TURBULENCE ALERT',
    script:
        'Ladies and gentlemen, we are experiencing an area of '
        'turbulence. Please return to your seats immediately and keep your '
        'seat belts securely fastened. Cabin service has been suspended. '
        'Thank you.',
  ),
  PramItem(
    id: 'descent',
    code: '06',
    title: 'DESCENT PREPARATION',
    script:
        'Ladies and gentlemen, we have started our descent. Please '
        'return to your seats, make sure your seat belts are fastened, your '
        'seat backs are upright, your tray tables are stowed, and your window '
        'shades are open. Electronic devices must be in flight mode. '
        'Cabin crew, prepare the cabin for landing.',
  ),
  PramItem(
    id: 'arrival',
    code: '07',
    title: 'ARRIVAL / DISEMBARK',
    script:
        'Ladies and gentlemen, welcome to your destination. Please remain '
        'seated with your seat belts fastened until the aircraft has come to '
        'a complete stop and the seat belt sign has been switched off. Use '
        'caution when opening the overhead bins. Thank you for flying with '
        'us.',
  ),
];
