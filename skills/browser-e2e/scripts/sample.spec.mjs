// Sample browser journeys for the tide-reading fixture.
// Run against the loopback server from serve-fixture.mjs. Retain the trace of
// the deliberate failure; a green rerun does not replace that evidence.

export const journeys = [
  {
    name: 'saves a tide reading',
    steps: [
      'Open the fixture over http://127.0.0.1.',
      'Focus the Tide time field with the keyboard and type 06:12.',
      'Activate Save reading with Enter.',
      'Expect the readings list to show 06:12 and the empty note to be gone.',
    ],
  },
  {
    name: 'refuses a blank tide time',
    seededDefect: 'The blank value is submitted and a row is added instead of being refused.',
    steps: [
      'Open the fixture over http://127.0.0.1.',
      'Leave Tide time empty and activate Save reading with the keyboard.',
      'Expect the text "Tide time is required." and no new row.',
    ],
    trace: 'Keep the trace for this journey. It shows whether the row count grew.',
  },
];
