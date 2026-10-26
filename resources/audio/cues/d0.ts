export type Cue = { id: string; file: string; rate: number; seconds: number; kind: string; music: boolean; notes?: number[] };
export const cues: Cue[] = [
 {id:'sfx.cup_down',file:'cup_down.wav',rate:44100,seconds:.22,kind:'wood',music:false},
 {id:'sfx.cup_up',file:'cup_up.wav',rate:44100,seconds:.28,kind:'bell',music:false},
 {id:'sting.exposed',file:'exposed.wav',rate:44100,seconds:2,kind:'gong',music:false},
 {id:'music.d0_theme',file:'d0_theme.wav',rate:22050,seconds:8,kind:'theme',music:true,notes:[72,76,79,81,76,72,81,79]},
];
