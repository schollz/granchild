Engine_ZGlut : CroneEngine {
	classvar nvoices = 4;

	var pg;
	var effect;
	var <buffers;
	var <voices;
	var effectBus;
	var <phases;
	var <levels;

	var <seek_tasks;

	// Kolor specific v0.1.0
	var sampleBuffKolor;
	var samplePlayerKolor;
	// Kolor ^

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	// disk read
	readBuf { arg i, path;
		if(buffers[i].notNil, {
			if (File.exists(path), {
				// TODO: load stereo files and duplicate GrainBuf for stereo granulation
				var newbuf = Buffer.readChannel(context.server, path, 0, -1, [0], {
					voices[i].set(\buf, newbuf);
					buffers[i].free;
					buffers[i] = newbuf;
				});
			});
		});
	}

	alloc {
		buffers = Array.fill(nvoices, { arg i;
			Buffer.alloc(
				context.server,
				context.server.sampleRate * 1,
			);
		});

		SynthDef(\synth, {
			arg out, effectBus, phase_out, level_out, buf,
			gate=0, pos=0, speed=1, jitter=0,
			size=0.1, density=20, pitch=1, spread=0, gain=1, envscale=1,
			freeze=0, t_reset_pos=0, cutoff=20000, q, mode=0, send=0;

			var grain_trig;
			var trig_rnd;
			var jitter_sig;
			var buf_dur;
			var pan_sig;
			var buf_pos;
			var pos_sig;
			var sig;

			var env;
			var level;

			density = Lag.kr(density);
			spread = Lag.kr(spread);
			size = Lag.kr(size);
			cutoff = Lag.kr(cutoff);
			q = Lag.kr(q);
			send = Lag.kr(send);
			
			grain_trig = Impulse.kr(density);
			buf_dur = BufDur.kr(buf);

			pan_sig = TRand.kr(trig: grain_trig,
				lo: spread.neg,
				hi: spread);

			jitter_sig = TRand.kr(trig: grain_trig,
				lo: buf_dur.reciprocal.neg * jitter,
				hi: buf_dur.reciprocal * jitter);

			buf_pos = Phasor.kr(trig: t_reset_pos,
				rate: buf_dur.reciprocal / ControlRate.ir * speed,
				resetPos: pos);

			pos_sig = Wrap.kr(Select.kr(freeze, [buf_pos, pos]));

			sig = GrainBuf.ar(2, grain_trig, size, buf, pitch, pos_sig + jitter_sig, 2, pan_sig);
			sig = BLowPass4.ar(sig, cutoff, q);

			env = EnvGen.kr(Env.asr(1, 1, 1), gate: gate, timeScale: envscale);

			level = env;

			Out.ar(out, sig * level * gain);
			Out.ar(effectBus, sig * level * send * gain);
			Out.kr(phase_out, pos_sig);
			// ignore gain for level out
			Out.kr(level_out, level);
		}).add;

		SynthDef(\effect, {
			arg in, out, delayTime=2.0, damp=0.1, size=4.0, diff=0.7, feedback=0.2, modDepth=0.1, modFreq=0.1, delayVol=1.0;
			var sig = In.ar(in, 2);
			sig = Greyhole.ar(sig, delayTime, damp, size, diff, feedback, modDepth, modFreq);
			Out.ar(out, sig * delayVol);
		}).add;

		context.server.sync;

		// delay bus
    effectBus = Bus.audio(context.server, 2);
    
		effect = Synth.new(\effect, [\in, effectBus.index, \out, context.out_b.index], target: context.xg);

		phases = Array.fill(nvoices, { arg i; Bus.control(context.server); });
		levels = Array.fill(nvoices, { arg i; Bus.control(context.server); });

		pg = ParGroup.head(context.xg);

		voices = Array.fill(nvoices, { arg i;
			Synth.new(\synth, [
				\out, context.out_b.index,
				\effectBus, effectBus.index,
				\phase_out, phases[i].index,
				\level_out, levels[i].index,
				\buf, buffers[i],
			], target: pg);
		});

		context.server.sync;

		this.addCommand("delay_time", "f", { arg msg; effect.set(\delayTime, msg[1]); });
		this.addCommand("delay_damp", "f", { arg msg; effect.set(\damp, msg[1]); });
		this.addCommand("delay_size", "f", { arg msg; effect.set(\size, msg[1]); });
		this.addCommand("delay_diff", "f", { arg msg; effect.set(\diff, msg[1]); });
		this.addCommand("delay_fdbk", "f", { arg msg; effect.set(\feedback, msg[1]); });
		this.addCommand("delay_mod_depth", "f", { arg msg; effect.set(\modDepth, msg[1]); });
		this.addCommand("delay_mod_freq", "f", { arg msg; effect.set(\modFreq, msg[1]); });
		this.addCommand("delay_volume", "f", { arg msg; effect.set(\delayVol, msg[1]); });

		this.addCommand("read", "is", { arg msg;
			this.readBuf(msg[1] - 1, msg[2]);
		});

		this.addCommand("seek", "if", { arg msg;
			var voice = msg[1] - 1;
			var lvl, pos;
			var seek_rate = 1 / 750;

			seek_tasks[voice].stop;

			// TODO: async get
			lvl = levels[voice].getSynchronous();

			if (false, { // disable seeking until fully implemented
				var step;
				var target_pos;

				// TODO: async get
				pos = phases[voice].getSynchronous();
				voices[voice].set(\freeze, 1);

				target_pos = msg[2];
				step = (target_pos - pos) * seek_rate;

				seek_tasks[voice] = Routine {
					while({ abs(target_pos - pos) > abs(step) }, {
						pos = pos + step;
						voices[voice].set(\pos, pos);
						seek_rate.wait;
					});

					voices[voice].set(\pos, target_pos);
					voices[voice].set(\freeze, 0);
					voices[voice].set(\t_reset_pos, 1);
				};

				seek_tasks[voice].play();
			}, {
				pos = msg[2];

				voices[voice].set(\pos, pos);
				voices[voice].set(\t_reset_pos, 1);
				voices[voice].set(\freeze, 0);
			});
		});

		this.addCommand("gate", "ii", { arg msg;
			var voice = msg[1] - 1;
			voices[voice].set(\gate, msg[2]);
		});

		this.addCommand("speed", "if", { arg msg;
			var voice = msg[1] - 1;
			voices[voice].set(\speed, msg[2]);
		});

		this.addCommand("jitter", "if", { arg msg;
			var voice = msg[1] - 1;
			voices[voice].set(\jitter, msg[2]);
		});

		this.addCommand("size", "if", { arg msg;
			var voice = msg[1] - 1;
			voices[voice].set(\size, msg[2]);
		});

		this.addCommand("density", "if", { arg msg;
			var voice = msg[1] - 1;
			voices[voice].set(\density, msg[2]);
		});

		this.addCommand("pitch", "if", { arg msg;
			var voice = msg[1] - 1;
			voices[voice].set(\pitch, msg[2]);
		});

		this.addCommand("spread", "if", { arg msg;
			var voice = msg[1] - 1;
			voices[voice].set(\spread, msg[2]);
		});

		this.addCommand("gain", "if", { arg msg;
			var voice = msg[1] - 1;
			voices[voice].set(\gain, msg[2]);
		});

		this.addCommand("envscale", "if", { arg msg;
			var voice = msg[1] - 1;
			voices[voice].set(\envscale, msg[2]);
		});
		
		this.addCommand("cutoff", "if", { arg msg;
		var voice = msg[1] -1;
		voices[voice].set(\cutoff, msg[2]);
		});
		
		this.addCommand("q", "if", { arg msg;
		var voice = msg[1] -1;
		voices[voice].set(\q, msg[2]);
		});
		
		this.addCommand("send", "if", { arg msg;
		var voice = msg[1] -1;
		voices[voice].set(\send, msg[2]);
		});
		
		this.addCommand("volume", "if", { arg msg;
			var voice = msg[1] - 1;
			voices[voice].set(\gain, msg[2]);
		});

		// nvoices.do({ arg i;
		// 	this.addPoll(("phase_" ++ (i+1)).asSymbol, {
		// 		var val = phases[i].getSynchronous;
		// 		val
		// 	});

		// 	this.addPoll(("level_" ++ (i+1)).asSymbol, {
		// 		var val = levels[i].getSynchronous;
		// 		val
		// 	});
		// });

		seek_tasks = Array.fill(nvoices, { arg i;
			Routine {}
		});



		// Kolor specific v0.1.0
		sampleBuffKolor = Array.fill(12, { arg i; 
			Buffer.read(context.server, "/home/we/dust/code/kolor/samples/silence.wav"); 
		});

		(0..12).do({arg i; 
			SynthDef("player"++i,{ arg sampleBufnum=0, t_trig=0, lfolfo=0.0, currentTime=0.0, 
				ampMin=0.0, ampMax=0.0, ampLFOMin=0.0, ampLFOMax=0.0, 
				rateMin=1.0, rateMax=1.0, rateLFOMin=0.0, rateLFOMax=0.0,
				panMin=0.0, panMax=0.0, panLFOMin=0.0, panLFOMax=0.0,
				lpfMin=20000.0, lpfMax=20000.0, lpfLFOMin=0.0, lpfLFOMax=0.0,
				resonanceMin=2.0, resonanceMax=2.0, resonanceLFOMin=0.0, resonanceLFOMax=0.0,
				hpfMin=10.0, hpfMax=10.0, hpfLFOMin=0.0, hpfLFOMax=0.0,
				sampleStartMin=0.0, sampleStartMax=0.0, sampleStartLFOMin=0.0, sampleStartLFOMax=0.0,
				sampleEndMin=1.0, sampleEndMax=1.0, sampleEndLFOMin=0.0, sampleEndLFOMax=0.0,
				retrigMin=1.0, retrigMax=1.0, retrigLFOMin=0.0, retrigLFOMax=0.0,
				delaySendMin=1.0, delaySendMax=1.0, delaySendLFOMin=0.0, delaySendLFOMax=0.0,
				delayFeedbackMin=1.0, delayFeedbackMax=1.0, delayFeedbackLFOMin=0.0, delayFeedbackLFOMax=0.0,
				secondsPerBeat=0.5,t_gate=0;
				
				var amp, rate, pan, lpf, resonance, hpf, sampleStart, sampleEnd, snd, bufsnd, delaySend, delayFeedback, retrig;
				
				// lfo modulation
				amp = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*ampLFOMin).mod(2*pi),mul:(ampLFOMax-ampLFOMin),add:(ampLFOMax+ampLFOMin)/2),
					(currentTime*2*pi*ampLFOMin).mod(2*pi),mul:(ampMax-ampMin)/2,add:(ampMax+ampMin)/2
				);
				rate = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*rateLFOMin).mod(2*pi),mul:(rateLFOMax-rateLFOMin),add:(rateLFOMax+rateLFOMin)/2),
					(currentTime*2*pi*rateLFOMin).mod(2*pi),mul:(rateMax-rateMin)/2,add:(rateMax+rateMin)/2
				);
				pan = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*panLFOMin).mod(2*pi),mul:(panLFOMax-panLFOMin),add:(panLFOMax+panLFOMin)/2),
					(currentTime*2*pi*panLFOMin).mod(2*pi),mul:(panMax-panMin)/2,add:(panMax+panMin)/2
				);
				lpf = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*lpfLFOMin).mod(2*pi),mul:(lpfLFOMax-lpfLFOMin),add:(lpfLFOMax+lpfLFOMin)/2),
					(currentTime*2*pi*lpfLFOMin).mod(2*pi),mul:(lpfMax-lpfMin)/2,add:(lpfMax+lpfMin)/2
				);
				resonance = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*resonanceLFOMin).mod(2*pi),mul:(resonanceLFOMax-resonanceLFOMin),add:(resonanceLFOMax+resonanceLFOMin)/2),
					(currentTime*2*pi*resonanceLFOMin).mod(2*pi),mul:(resonanceMax-resonanceMin)/2,add:(resonanceMax+resonanceMin)/2
				);
				hpf = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*hpfLFOMin).mod(2*pi),mul:(hpfLFOMax-hpfLFOMin),add:(hpfLFOMax+hpfLFOMin)/2),
					(currentTime*2*pi*hpfLFOMin).mod(2*pi),mul:(hpfMax-hpfMin)/2,add:(hpfMax+hpfMin)/2
				);
				sampleStart = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*sampleStartLFOMin).mod(2*pi),mul:(sampleStartLFOMax-sampleStartLFOMin),add:(sampleStartLFOMax+sampleStartLFOMin)/2),
					(currentTime*2*pi*sampleStartLFOMin).mod(2*pi),mul:(sampleStartMax-sampleStartMin)/2,add:(sampleStartMax+sampleStartMin)/2
				);
				sampleEnd = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*sampleEndLFOMin).mod(2*pi),mul:(sampleEndLFOMax-sampleEndLFOMin),add:(sampleEndLFOMax+sampleEndLFOMin)/2),
					(currentTime*2*pi*sampleEndLFOMin).mod(2*pi),mul:(sampleEndMax-sampleEndMin)/2,add:(sampleEndMax+sampleEndMin)/2
				);
				retrig = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*retrigLFOMin).mod(2*pi),mul:(retrigLFOMax-retrigLFOMin),add:(retrigLFOMax+retrigLFOMin)/2),
					(currentTime*2*pi*retrigLFOMin).mod(2*pi),mul:(retrigMax-retrigMin)/2,add:(retrigMax+retrigMin)/2
				);
				delaySend = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*delaySendLFOMin).mod(2*pi),mul:(delaySendLFOMax-delaySendLFOMin),add:(delaySendLFOMax+delaySendLFOMin)/2),
					(currentTime*2*pi*delaySendLFOMin).mod(2*pi),mul:(delaySendMax-delaySendMin)/2,add:(delaySendMax+delaySendMin)/2
				);
				delayFeedback = SinOsc.kr(
					SinOsc.kr(lfolfo,(currentTime*2*pi*delayFeedbackLFOMin).mod(2*pi),mul:(delayFeedbackLFOMax-delayFeedbackLFOMin),add:(delayFeedbackLFOMax+delayFeedbackLFOMin)/2),
					(currentTime*2*pi*delayFeedbackLFOMin).mod(2*pi),mul:(delayFeedbackMax-delayFeedbackMin)/2,add:(delayFeedbackMax+delayFeedbackMin)/2
				);
				
				bufsnd = BufRd.ar(2,sampleBufnum,
					Phasor.ar(
						trig:t_trig,
						rate:BufRateScale.kr(sampleBufnum)*rate,
						// start:sampleStart*BufFrames.kr(sampleBufnum),
						// end:sampleEnd*BufFrames.kr(sampleBufnum),
						// resetPos:sampleStart*BufFrames.kr(sampleBufnum)
						start:((sampleStart*(rate>0))+(sampleEnd*(rate<0)))*BufFrames.kr(sampleBufnum),
						end:((sampleEnd*(rate>0))+(sampleStart*(rate<0)))*BufFrames.kr(sampleBufnum),
						resetPos:((sampleStart*(rate>0))+(sampleEnd*(rate<0)))*BufFrames.kr(sampleBufnum)
					)
					loop:(retrig>0),
					interpolation:1
				);
				// bufsnd = PlayBuf.ar(2, sampleBufnum,
				// 	rate:rate*BufRateScale.kr(sampleBufnum),
				// 	startPos:sampleStart*BufFrames.kr(sampleBufnum),
				// 	loop:retrig, // if > 0 then it loops, getting stopped by the envelope
				// 	trigger:t_trig);
	        		bufsnd = MoogFF.ar(bufsnd,lpf,resonance);
	        		bufsnd = HPF.ar(bufsnd,hpf);
				snd = Mix.ar([
					Pan2.ar(bufsnd[0],-1+(2*pan),amp),
					Pan2.ar(bufsnd[1],1+(2*pan),amp),
				]);
				Out.ar(0,
					snd*EnvGen.ar(Env([0,1, 1, 0], [0.005,(sampleEnd-sampleStart)/(rate.abs)*(retrig+1)*BufDur.kr(sampleBufnum)-0.015,0.005]),gate:t_gate) +
					CombN.ar(
						snd*EnvGen.ar(Env([0,1, 1, 0], [0.005,(sampleEnd-sampleStart)/(rate.abs)*(retrig+1)*BufDur.kr(sampleBufnum)-0.015,0.005]),gate:t_gate),
						1,secondsPerBeat/8*2,secondsPerBeat/8*delayFeedback,0.75*delaySend // delayFeedback should vary between 2 and 128
					)
				)
			}).add;	
		});

		samplePlayerKolor = Array.fill(12,{arg i;
			Synth("player"++i,[\bufnum:sampleBuffKolor[i]], target:context.xg);
		});

		this.addCommand("kolorsample","is", { arg msg;
			// lua is sending 1-index
			sampleBuffKolor[msg[1]-1].free;
			sampleBuffKolor[msg[1]-1] = Buffer.read(context.server,msg[2]);
		});

		this.addCommand("kolorplay","iffffffffffffffffffffffffffffffffffffffffffffffff", { arg msg;
			// lua is sending 1-index
			samplePlayerKolor[msg[1]-1].set(
				\t_trig,1,
				\currentTime, msg[2],
				\ampMin,msg[3],\ampMax,msg[4],\ampLFOMin,msg[5],\ampLFOMax,msg[6],
				\rateMin,msg[7],\rateMax,msg[8],\rateLFOMin,msg[9],\rateLFOMax,msg[10],
				\panMin,msg[11],\panMax,msg[12],\panLFOMin,msg[13],\panLFOMax,msg[14],
				\lpfMin,msg[15],\lpfMax,msg[16],\lpfLFOMin,msg[17],\lpfLFOMax,msg[18],
				\resonanceMin,msg[19],\resonanceMax,msg[20],\resonanceLFOMin,msg[21],\resonanceLFOMax,msg[22],
				\hpfMin,msg[23],\hpfMax,msg[24],\hpfLFOMin,msg[25],\hpfLFOMax,msg[26],
				\sampleStartMin,msg[27],\sampleStartMax,msg[28],\sampleStartLFOMin,msg[29],\sampleStartLFOMax,msg[30],
				\sampleEndMin,msg[31],\sampleEndMax,msg[32],\sampleEndLFOMin,msg[33],\sampleEndLFOMax,msg[34],
				\retrigMin,msg[35],\retrigMax,msg[36],\retrigLFOMin,msg[37],\retrigLFOMax,msg[38],
				\delaySendMin,msg[39],\delaySendMax,msg[40],\delaySendLFOMin,msg[41],\delaySendLFOMax,msg[42],
				\delayFeedbackMin,msg[43],\delayFeedbackMax,msg[44],\delayFeedbackLFOMin,msg[45],\delayFeedbackLFOMax,msg[46],
				\lfolfo,msg[47],
				\sampleBufnum,sampleBuffKolor[msg[48]-1],
				\secondsPerBeat,msg[49],
				\t_gate,1
			);
		});
		// Kolor ^

	}

	free {
		voices.do({ arg voice; voice.free; });
		phases.do({ arg bus; bus.free; });
		levels.do({ arg bus; bus.free; });
		buffers.do({ arg b; b.free; });
		effect.free;
		effectBus.free;
		// Kolor specific 0.1.0
		(0..11).do({arg i; sampleBuffKolor[i].free});
		(0..11).do({arg i; samplePlayerKolor[i].free});
		// Kolor ^
	}
}
