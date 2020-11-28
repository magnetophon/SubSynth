declare author "Bart Brouns";
declare license "AGPLv3";
declare name "lastNote";
declare options "[midi:on][nvoices:1]";

import("stdfaust.lib");

process =
  SubS(freq,gain,gate);

///////////////////////////////////////////////////////////////////////////////
//                                   synth                                   //
///////////////////////////////////////////////////////////////////////////////

SubS(freq,gain,gate) =
  subOsc(targetFreq,freq,punch,gate:ba.impulsify ,gate)
  // * (vel(lastNote)/127)
  // * level
  :>_*gainEnvelope<:(_,_)
with {
  gainEnvelope = en.adsr(a,d,s,r,gate)*gain;
};


///////////////////////////////////////////////////////////////////////////////
//                                 oscillator                                //
///////////////////////////////////////////////////////////////////////////////


subOsc(target,freq,absFreqOffset,retrigger,gate) =
  slaveSine(fund)
 ,(slaveSine(fund*2:ma.frac))
  : xfade(fade)
    // :fi.lowpass(3,max(target*2,absFreqOffset)*hslider("LP", 2, 1, 200, 0.5):min(20000):hbargraph("filter", 0, 20000):si.smoo)
    // :fi.lowpass(3,max(target*2,punchFreq:ba.midikey2hz)*hslider("LP", 2, 1, 200, 0.5):min(20000):si.smoo)
with {
  PunchedFreq = ((subFreq:ba.hz2midikey)+(punchFreq*punchEnv)):ba.midikey2hz;
  punchFreq = (absFreqOffset:ba.hz2midikey)-(subFreq:ba.hz2midikey);
  subFreq = freq*oct/maxOct;
  punchEnv =
    gate:ba.impulsify:si.lag_ud(0,decayT);
  // hslider("pe", 0, 0, 1, 0.01);

  oct =
    pow2( octave )
    // :hbargraph("[41]octMeter", 0, 2^13)
  ;
  octave =
    ma.log2
    ((target/freq)*maxOct)
    +errorCorrection :int
                      // :hbargraph("[40]octaveMeter", 0, 20)
  ;
  // without this, we get the wrong octave when freq=110 and target=110
  singleprecision errorCorrection = 0;
  doubleprecision errorCorrection = 0;
  // found trough trial and error:
  quadprecision errorCorrection = 0.000000000000000044685;

  maxOct = pow2(baseOct);

  fade =
    (target/PunchedFreq)
    // :hbargraph("[32]target/PunchedFreq", 0, 2)
    -1:max(0):min(1)
              // :hbargraph("[30]fade", 0, 1)
  ;


  lf_sawpos_trig(freq,trig) = ma.frac * dontReset ~ +(freq/ma.SR)
  with {
    dontReset  = trig:ba.impulsify*-1+1;
  };
  masterOsc = lf_sawpos_trig(PunchedFreq/oct,gate);
  fund = masterOsc*(oct):ma.frac;
  slaveSine(fund) = fund*ma.PI*2:sin;
  xfade(x,a,b) = it.interpolate_linear(x,a,b);
};

///////////////////////////////////////////////////////////////////////////////
//                                    MIDI                                   //
///////////////////////////////////////////////////////////////////////////////

gain               = midi_group(hslider("[0]gain",0.5,0,1,0.01));
f                  = midi_group(hslider("[1]freq",maxFreq,minFreq,maxFreq,0.001));
b                  = midi_group(hslider("[2]bend [midi:pitchwheel]",0,-2,2,0.001):ba.semi2ratio): si.polySmooth(gate,0.999,1);
gate               = midi_group( button("[3]gate"));
// gate            = nrNotesPlaying>0;

freq               = f*b;
// freq            = (lastNote:ba.pianokey2hz) * b;
// freq            = target_group(hslider("freq", 110, 55, 880, 1):si.smoo);

a                  = envelope_group(hslider("[0]attack [tooltip: Attack time in seconds][unit:s] [scale:log]", 0, 0, 1, 0.001)): si.polySmooth(gate,0.999,1);
d                  = envelope_group(hslider("[1]decay [tooltip: Decay time in seconds][unit:s] [scale:log]", 0.5, 0, 1, 0.001)): si.polySmooth(gate,0.999,1);
s                  = envelope_group(hslider("[2]sustain [tooltip: Sustain level]", 0, 0, 1, 0.001)): si.polySmooth(gate,0.999,1);
r                  = envelope_group(hslider("[3]release [tooltip: Release time in seconds][unit:s] [scale:log]", 0.020, 0, 1, 0.001)): si.polySmooth(gate,0.999,1);

targetFreq         = punch_group(hslider("[0]target frequency", 45, 0, 127, 1)):ba.midikey2hz : si.polySmooth(gate,0.999,1);
// targetFreq      = target_group(hslider("target freq", 110, minFreq, 880, 1)
// : si.polySmooth(gate,0.999,1))
// ;
punch              = punch_group(hslider("[1]punch frequency", 69, 0, 127, 1)):ba.midikey2hz: si.polySmooth(gate,0.999,1);
decayT             = punch_group(hslider("[2]decay time", 0.02, 0, 0.8, 0.001)): si.polySmooth(gate,0.999,1);

retrigger          = checkbox("retrigger")*-1+1;
level              = target_group(hslider("level", 0, -60, 0, 1): si.polySmooth(gate,0.999,1):ba.db2linear);

tabs(x)            = tgroup("", x);
synth_group(x)     = tabs(hgroup("[0]synth", x));
midi_group(x)      = tabs(vgroup("[1]midi", x));
envelope_group(x)  = synth_group(vgroup("[0]envelope", x));
punch_group(x)     = synth_group(vgroup("[1]punch", x));
target_group(x)    = synth_group(vgroup("[2]target", x));
// target_group(x) = synth_group(vgroup("target", x);
///////////////////////////////////////////////////////////////////////////////
//                                 constants                                 //
///////////////////////////////////////////////////////////////////////////////

// we can ony shift octaves up, not down so start with the lowest possibly usefull octave divider:
// we want any note to be able to turn subsonic
// midi 127 = 12543.9 Hz
// 12543.9/(2^10) = 12.249902 Hz
minFreq = maxFreq/pow2(baseOct); // 12.249902;
maxFreq = 12543.9;
baseOct = 10;

pow2(i) = 1<<int(i);
// same as:
// pow2(i) = int(pow(2,i));
// but in the block diagram, it will be displayed as a number, instead of a formula

///////////////////////////////////////////////////////////////////////////////
//                                  lastNote                                 //
//           give the number of the last note played                         //
///////////////////////////////////////////////////////////////////////////////


// increases the cpu-usage, from 7% to 11%
// * (vel(lastNote)/127)
// no velocity:
// * (nrNotesPlaying>0)
// ;



nrNotesPlaying = 0: seq(i, nrNotes, noteIsOn(i),_:+);
noteIsOn(i) = velocity(i)>0;

vel(x) =  par(i, nrNotes, velocity(i)*(i==x)):>_ ;
velocity(i) = hslider("velocity of note %i [midi:key %i ]", 0, 0, nrNotes, 1);
nrNotes = 127; // nr of midi notes
// nrNotes = 32; // for block diagram

lastNote = par(i, nrNotes, i,index(i)):find_max_index(nrNotes):(_,!)
with {
  // an index to indicate the order of the note
  // it adds one for every additional note played
  // it resets to 0 when there are no notes playing
  // assume multiple notes can start at once
  orderIndex = ((_+((nrNotesPlaying-nrNotesPlaying'):max(0))) * (nrNotesPlaying>1))~_;

  // the order index of note i
  // TODO: when multiple notes start at the same time, give each a unique index
  index(i) = orderIndex:(select2(noteStart(i),_,_)
                         :select2(noteEnd(i)+(1:ba.impulsify),_,-1))~_;

  // we use this instead of:
  // hslider("frequency[midi:keyon 62]",0,0,nrNotes,1)
  // because keyon can come multiple times, and we only want the first
  noteStart(i) = noteIsOn(i):ba.impulsify;
  noteEnd(i) = (noteIsOn(i)'-noteIsOn(i)):max(0):ba.impulsify;
  //or do we?
  // noteStart(i) = (hslider("keyon[midi:keyon %i]",0,0,nrNotes,1)>0) :ba.impulsify;
  // at the very least, the first implementation of noteStart(i) doesn't add another 127 sliders

  // from Julius Smith's acor.dsp:
  index_comparator(n,x,m,y) = select2((x>y),m,n), select2((x>y),y,x); // compare integer-labeled signals
  // take N number-value pairs and give the number with the maximum value
  find_max_index(N) = seq(i,N-2, (index_comparator,si.bus(2*(N-i-2)))) : index_comparator;
};
