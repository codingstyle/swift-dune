//
//  OPL3.swift
//  SwiftDune
//
//  Ported from Nuked OPL3. Copyright (C) 2013-2020 Nuke.YKT
//  Original C code can be found at https://github.com/nukeykt/Nuked-OPL3
//
//  Created by Christophe Buguet on 30/07/2025.
//

import Foundation
import AVFoundation

public struct OPLWriteBuffer {
  var time: UInt64 = 0
  var reg: UInt16 = 0
  var data: UInt8 = 0
}

public final class OPLChip {
  var channel: [OPLChannel] = Array.init(repeating: OPLChannel(), count: 18) /* size = 18 */
  var slot: [OPLSlot] = Array.init(repeating: OPLSlot(), count: 36) /* size = 36 */
  var timer: UInt16 = 0
  var egTimer: UInt64 = 0
  var egTimerRem: UInt8 = 0
  var egState: UInt8 = 0
  var egAdd: UInt8 = 0
  var egTimerLo: UInt8 = 0
  var newm: UInt8 = 0
  var nts: UInt8 = 0
  var rhy: UInt8 = 0
  var vibpos: UInt8 = 0
  var vibshift: UInt8 = 0
  var tremolo: UInt8 = 0
  var tremolopos: UInt8 = 0
  var tremoloshift: UInt8 = 0
  var noise: UInt32 = 0
  var zeromod: Int16 = 0
  var mixbuff: [Int32] = Array.init(repeating: 0, count: 4) /* size = 4 */
  var rmHhBit2: UInt8 = 0
  var rmHhBit3: UInt8 = 0
  var rmHhBit7: UInt8 = 0
  var rmHhBit8: UInt8 = 0
  var rmTcBit3: UInt8 = 0
  var rmTcBit5: UInt8 = 0

#if OPL_ENABLE_STEREOEXT
  var stereoext: UInt8 = 0
#endif
  
  /* OPL3L */
  var rateratio: Int32 = 0
  var samplecnt: Int32 = 0
  var oldsamples: [Int16] = Array.init(repeating: 0, count: 4) /* size = 4 */
  var samples: [Int16] = Array.init(repeating: 0, count: 4) /* size = 4 */
  
  var writebufSampleCnt: UInt64 = 0
  var writebufCur: UInt32 = 0
  var writebufLast: UInt32 = 0
  var writebufLastTime: UInt64 = 0

  var writebuf: [OPLWriteBuffer] = Array.init(repeating: OPLWriteBuffer(), count: 1024) /* OPL_WRITEBUF_SIZE = 1024 */
  
  init() { }
}



public final class OPLChannel {
  var slotz: [OPLSlot] = Array.init(repeating: OPLSlot(), count: 2) /* size = 2. Don't use "slots" keyword to avoid conflict with Qt applications*/
  var pair: OPLChannel?
  var chip: OPLChip?
  var out = [UnsafeMutablePointer<Int16>?](repeating: nil, count: 4) /* int16_t *out[4]; */
  
#if OPL_ENABLE_STEREOEXT
  var leftPan: Int32 = 0
  var rightPan: Int32 = 0
#endif
  
  var chType: OPLChannelType = .channel2op
  var fNum: UInt16 = 0
  var block: UInt8 = 0
  var fb: UInt8 = 0
  var con: UInt8 = 0
  var alg: UInt8 = 0
  var ksv: UInt8 = 0
  var cha: UInt16 = 0
  var chb: UInt16 = 0
  var chc: UInt16 = 0
  var chd: UInt16 = 0
  var chNum: UInt8 = 0
  
  init() { }
}


public final class OPLSlot {
  var channel: OPLChannel?
  var chip: OPLChip?
  var out: Int16 = 0
  var fbMod: Int16 = 0
  var mod: UnsafeMutablePointer<Int16>?
  var prOut: Int16 = 0
  var egRout: UInt16 = 0
  var egOut: UInt16 = 0
  var egInc: UInt8 = 0
  var egGen: OPLEnvelopeGenNumber = .attack
  var egRate: UInt8 = 0
  var egKsl: UInt8 = 0
  var trem: UnsafeMutablePointer<UInt8>?
  var regVib: UInt8 = 0
  var regType: UInt8 = 0
  var regKsr: UInt8 = 0
  var regMult: UInt8 = 0
  var regKsl: UInt8 = 0
  var regTl: UInt8 = 0
  var regAr: UInt8 = 0
  var regDr: UInt8 = 0
  var regSl: UInt8 = 0
  var regRr: UInt8 = 0
  var regWf: UInt8 = 0
  var key: UInt8 = 0
  var pgReset: UInt32 = 0
  var pgPhase: UInt32 = 0
  var pgPhaseOut: UInt16 = 0
  var slotNum: UInt8 = 0
  
  init() { }
}


enum OPLChannelType : Int
{
  case channel2op = 0
  case channel4op = 1
  case channel4op2 = 2
  case channelDrum = 3
}

enum OPLEnvelopeKeyType : Int
{
  case normal = 0
  case drum = 1
}

enum OPLEnvelopeGenNumber : Int
{
  case attack = 0
  case decay = 1
  case sustain = 2
  case release = 3
}


//
// OPL3 Emulator for HERAD music synthesis
//
public final class OPL3 {
  private let rsmFrac = 10
  private let oplWritebufSize = 1024
  private let oplWritebufDelay = 2
  
  // Logsin table
  private let logSinRom: [UInt16] = [
    0x859, 0x6c3, 0x607, 0x58b, 0x52e, 0x4e4, 0x4a6, 0x471,
    0x443, 0x41a, 0x3f5, 0x3d3, 0x3b5, 0x398, 0x37e, 0x365,
    0x34e, 0x339, 0x324, 0x311, 0x2ff, 0x2ed, 0x2dc, 0x2cd,
    0x2bd, 0x2af, 0x2a0, 0x293, 0x286, 0x279, 0x26d, 0x261,
    0x256, 0x24b, 0x240, 0x236, 0x22c, 0x222, 0x218, 0x20f,
    0x206, 0x1fd, 0x1f5, 0x1ec, 0x1e4, 0x1dc, 0x1d4, 0x1cd,
    0x1c5, 0x1be, 0x1b7, 0x1b0, 0x1a9, 0x1a2, 0x19b, 0x195,
    0x18f, 0x188, 0x182, 0x17c, 0x177, 0x171, 0x16b, 0x166,
    0x160, 0x15b, 0x155, 0x150, 0x14b, 0x146, 0x141, 0x13c,
    0x137, 0x133, 0x12e, 0x129, 0x125, 0x121, 0x11c, 0x118,
    0x114, 0x10f, 0x10b, 0x107, 0x103, 0x0ff, 0x0fb, 0x0f8,
    0x0f4, 0x0f0, 0x0ec, 0x0e9, 0x0e5, 0x0e2, 0x0de, 0x0db,
    0x0d7, 0x0d4, 0x0d1, 0x0cd, 0x0ca, 0x0c7, 0x0c4, 0x0c1,
    0x0be, 0x0bb, 0x0b8, 0x0b5, 0x0b2, 0x0af, 0x0ac, 0x0a9,
    0x0a7, 0x0a4, 0x0a1, 0x09f, 0x09c, 0x099, 0x097, 0x094,
    0x092, 0x08f, 0x08d, 0x08a, 0x088, 0x086, 0x083, 0x081,
    0x07f, 0x07d, 0x07a, 0x078, 0x076, 0x074, 0x072, 0x070,
    0x06e, 0x06c, 0x06a, 0x068, 0x066, 0x064, 0x062, 0x060,
    0x05e, 0x05c, 0x05b, 0x059, 0x057, 0x055, 0x053, 0x052,
    0x050, 0x04e, 0x04d, 0x04b, 0x04a, 0x048, 0x046, 0x045,
    0x043, 0x042, 0x040, 0x03f, 0x03e, 0x03c, 0x03b, 0x039,
    0x038, 0x037, 0x035, 0x034, 0x033, 0x031, 0x030, 0x02f,
    0x02e, 0x02d, 0x02b, 0x02a, 0x029, 0x028, 0x027, 0x026,
    0x025, 0x024, 0x023, 0x022, 0x021, 0x020, 0x01f, 0x01e,
    0x01d, 0x01c, 0x01b, 0x01a, 0x019, 0x018, 0x017, 0x017,
    0x016, 0x015, 0x014, 0x014, 0x013, 0x012, 0x011, 0x011,
    0x010, 0x00f, 0x00f, 0x00e, 0x00d, 0x00d, 0x00c, 0x00c,
    0x00b, 0x00a, 0x00a, 0x009, 0x009, 0x008, 0x008, 0x007,
    0x007, 0x007, 0x006, 0x006, 0x005, 0x005, 0x005, 0x004,
    0x004, 0x004, 0x003, 0x003, 0x003, 0x002, 0x002, 0x002,
    0x002, 0x001, 0x001, 0x001, 0x001, 0x001, 0x001, 0x001,
    0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000
  ]
  
  // Exponential table
  private let expRom: [UInt16] = [
    0x7fa, 0x7f5, 0x7ef, 0x7ea, 0x7e4, 0x7df, 0x7da, 0x7d4,
    0x7cf, 0x7c9, 0x7c4, 0x7bf, 0x7b9, 0x7b4, 0x7ae, 0x7a9,
    0x7a4, 0x79f, 0x799, 0x794, 0x78f, 0x78a, 0x784, 0x77f,
    0x77a, 0x775, 0x770, 0x76a, 0x765, 0x760, 0x75b, 0x756,
    0x751, 0x74c, 0x747, 0x742, 0x73d, 0x738, 0x733, 0x72e,
    0x729, 0x724, 0x71f, 0x71a, 0x715, 0x710, 0x70b, 0x706,
    0x702, 0x6fd, 0x6f8, 0x6f3, 0x6ee, 0x6e9, 0x6e5, 0x6e0,
    0x6db, 0x6d6, 0x6d2, 0x6cd, 0x6c8, 0x6c4, 0x6bf, 0x6ba,
    0x6b5, 0x6b1, 0x6ac, 0x6a8, 0x6a3, 0x69e, 0x69a, 0x695,
    0x691, 0x68c, 0x688, 0x683, 0x67f, 0x67a, 0x676, 0x671,
    0x66d, 0x668, 0x664, 0x65f, 0x65b, 0x657, 0x652, 0x64e,
    0x649, 0x645, 0x641, 0x63c, 0x638, 0x634, 0x630, 0x62b,
    0x627, 0x623, 0x61e, 0x61a, 0x616, 0x612, 0x60e, 0x609,
    0x605, 0x601, 0x5fd, 0x5f9, 0x5f5, 0x5f0, 0x5ec, 0x5e8,
    0x5e4, 0x5e0, 0x5dc, 0x5d8, 0x5d4, 0x5d0, 0x5cc, 0x5c8,
    0x5c4, 0x5c0, 0x5bc, 0x5b8, 0x5b4, 0x5b0, 0x5ac, 0x5a8,
    0x5a4, 0x5a0, 0x59c, 0x599, 0x595, 0x591, 0x58d, 0x589,
    0x585, 0x581, 0x57e, 0x57a, 0x576, 0x572, 0x56f, 0x56b,
    0x567, 0x563, 0x560, 0x55c, 0x558, 0x554, 0x551, 0x54d,
    0x549, 0x546, 0x542, 0x53e, 0x53b, 0x537, 0x534, 0x530,
    0x52c, 0x529, 0x525, 0x522, 0x51e, 0x51b, 0x517, 0x514,
    0x510, 0x50c, 0x509, 0x506, 0x502, 0x4ff, 0x4fb, 0x4f8,
    0x4f4, 0x4f1, 0x4ed, 0x4ea, 0x4e7, 0x4e3, 0x4e0, 0x4dc,
    0x4d9, 0x4d6, 0x4d2, 0x4cf, 0x4cc, 0x4c8, 0x4c5, 0x4c2,
    0x4be, 0x4bb, 0x4b8, 0x4b5, 0x4b1, 0x4ae, 0x4ab, 0x4a8,
    0x4a4, 0x4a1, 0x49e, 0x49b, 0x498, 0x494, 0x491, 0x48e,
    0x48b, 0x488, 0x485, 0x482, 0x47e, 0x47b, 0x478, 0x475,
    0x472, 0x46f, 0x46c, 0x469, 0x466, 0x463, 0x460, 0x45d,
    0x45a, 0x457, 0x454, 0x451, 0x44e, 0x44b, 0x448, 0x445,
    0x442, 0x43f, 0x43c, 0x439, 0x436, 0x433, 0x430, 0x42d,
    0x42a, 0x428, 0x425, 0x422, 0x41f, 0x41c, 0x419, 0x416,
    0x414, 0x411, 0x40e, 0x40b, 0x408, 0x406, 0x403, 0x400
  ]
  
  // freq mult table multiplied by 2
  private let mt: [UInt8] = [
    1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 24, 24, 30, 30
  ]
  
  // KSL table
  private let kslRom: [UInt8] = [
    0, 32, 40, 45, 48, 51, 53, 55, 56, 58, 59, 60, 61, 62, 63, 64
  ]
  
  private let kslShift: [UInt8] = [
    8, 1, 2, 0
  ]
  
  // Envelope generator constants
  private let egIncStep: [[UInt8]] = [
    [ 0, 0, 0, 0 ],
    [ 1, 0, 0, 0 ],
    [ 1, 0, 1, 0 ],
    [ 1, 1, 1, 0 ]
  ]
  
  // Address decoding
  private let adSlot: [Int8] = [
    0, 1, 2, 3, 4, 5, -1, -1, 6, 7, 8, 9, 10, 11, -1, -1,
    12, 13, 14, 15, 16, 17, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
  ]
  
  private let chSlot: [UInt8] = [
    0, 1, 2, 6, 7, 8, 12, 13, 14, 18, 19, 20, 24, 25, 26, 30, 31, 32
  ]
  
  private var panpotLUT: [Int32] = []
  private var panpotLUTBuild: UInt8 = 0
  
// MARK: Envelope generator
  /*
   typedef int16_t(*envelope_sinfunc)(uint16_t phase, uint16_t envelope);
   typedef void(*envelope_genfunc)(opl3_slot *slott);
   */
  
  ///
  /// Converts value to an OPL3 compatible sinus value
  /// Input [0, 256) -> [0, 65536]
  ///
  static func oplSin(_ x: Double) -> Int32 {
    return Int32((sin(x) * Math.PI / 512.0) * 65536.0)
  }
  
  
  private func envelopeCalcExp(_ level: UInt32) -> Int16 {
    var level = Int(level)
    
    if (level > 0x1fff) {
      level = 0x1fff
    }
    
    return Int16(truncatingIfNeeded: (expRom[level & 0xFF] << 1) >> (level >> 8))
  }
  
  
  private func envelopeCalcSin0(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
    var out: UInt16 = 0
    var neg: UInt16 = 0
    var phase = phase
    
    phase &= 0x3FF
    
    if (phase & 0x200) != 0 {
      neg = 0xFFFF
    }
    
    if (phase & 0x100) != 0 {
      out = logSinRom[Int(phase & 0xFF) ^ 0xFF]
    } else {
      out = logSinRom[Int(phase & 0xFF)]
    }
    
    let level = UInt32(out + (envelope << 3))
    return envelopeCalcExp(level) ^ Int16(bitPattern: neg)
  }
  
  
  private func envelopeCalcSin1(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
    var out: UInt16 = 0
    var phase = phase
    
    phase &= 0x3FF
    
    if (phase & 0x200) != 0 {
      out = 0x1000
    } else if (phase & 0x100) != 0 {
      out = logSinRom[Int(phase & 0xFF) ^ 0xFF]
    } else {
      out = logSinRom[Int(phase & 0xFF)]
    }
    
    let level = UInt32(out + (envelope << 3))
    return envelopeCalcExp(level)
  }
  
  
  private func envelopeCalcSin2(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
    var out: UInt16 = 0
    var phase = phase
    
    phase &= 0x3FF
    
    if (phase & 0x100) != 0 {
      out = logSinRom[Int(phase & 0xFF) ^ 0xFF]
    } else {
      out = logSinRom[Int(phase & 0xFF)]
    }
    
    let level = UInt32(out + (envelope << 3))
    return envelopeCalcExp(level)
  }
  
  
  private func envelopeCalcSin3(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
    var out: UInt16 = 0
    var phase = phase
    
    phase &= 0x3FF
    
    if (phase & 0x100) != 0 {
      out = 0x1000
    } else {
      out = logSinRom[Int(phase & 0xFF)]
    }
    
    let level = UInt32(out + (envelope << 3))
    return envelopeCalcExp(level)
  }
  
  
  private func envelopeCalcSin4(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
    var out: UInt16 = 0
    var neg: UInt16 = 0
    var phase = phase
    
    phase &= 0x3FF

    if (phase & 0x300) != 0 {
      neg = 0xFFFF
    } else if (phase & 0x200) != 0 {
      out = 0x1000
    } else if (phase & 0x80) != 0 {
      out = logSinRom[(Int(phase ^ 0xFF) << 1) & 0xFF]
    } else {
      out = logSinRom[Int(phase << 1) & 0xFF]
    }
    
    let level = UInt32(out + (envelope << 3))
    return envelopeCalcExp(level) ^ Int16(bitPattern: neg)
  }
  
  
  private func envelopeCalcSin5(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
    var out: UInt16 = 0
    var phase = phase
    
    phase &= 0x3FF
    
    if (phase & 0x200) != 0 {
      out = 0x1000
    } else if (phase & 0x80) != 0 {
      out = logSinRom[(Int(phase ^ 0xFF) << 1) & 0xFF]
    } else {
      out = logSinRom[Int(phase << 1) & 0xFF]
    }
    
    let level = UInt32(out + (envelope << 3))
    return envelopeCalcExp(level)
  }
  
  
  private func envelopeCalcSin6(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
    var neg: UInt16 = 0
    var phase = phase
    
    phase &= 0x3FF
    
    if (phase & 0x200) != 0 {
      neg = 0xFFFF
    }
    
    let level = UInt32(envelope << 3)
    return envelopeCalcExp(level) ^ Int16(bitPattern: neg)
  }
  
  
  private func envelopeCalcSin7(_ phase: UInt16, _ envelope: UInt16) -> Int16 {
    var out: UInt16 = 0
    var neg: UInt16 = 0
    var phase = phase
    
    phase &= 0x3FF
    
    if (phase & 0x200) != 0 {
      neg = 0xFFFF
      phase = (phase & 0x1FF) ^ 0x1FF
    }
    
    out = phase << 3
    
    let level = UInt32(out + (envelope << 3))
    return envelopeCalcExp(level) ^ Int16(bitPattern: neg)
  }
  
  
  private func envelopeUpdateKSL(_ slot: OPLSlot) {
    let ksl = Int16(kslRom[Int(slot.channel!.fNum) >> 6] << 2) - Int16((0x08 - slot.channel!.block) << 5)

    if ksl < 0 {
      slot.egKsl = 0
    } else {
      slot.egKsl = UInt8(ksl)
    }
  }
  
  
  private func envelopeCalc(_ slot: OPLSlot) {
    var reset: UInt32 = 0
    var regRate: UInt8 = 0
    
    let initialOut = slot.egRout + UInt16(slot.regTl << 2) + UInt16(slot.trem!.pointee)
    slot.egOut = UInt16(initialOut) + UInt16(slot.egKsl >> kslShift[Int(slot.regKsl)])

    if slot.key != 0 && slot.egGen == .release {
      reset = 1
      regRate = slot.regAr
    } else {
      switch slot.egGen {
          case .attack:
          regRate = slot.regAr
        case .decay:
          regRate = slot.regDr
        case .sustain:
          if slot.regType == 0 {
            regRate = slot.regRr
          }
          break
        case .release:
          regRate = slot.regRr
          break
      }
    }
    
    slot.pgReset = reset
    
    let ks = slot.channel!.ksv >> ((slot.regKsr ^ 1) << 1)
    let nonZero = (regRate != 0)
    let rate = ks + (regRate << 2)
    var rateHi = rate >> 2
    let rateLo = rate & 0x03
    
    if (rateHi & 0x10) != 0 {
      rateHi = 0x0F
    }
    
    let egShift: UInt8 = rateHi + slot.chip!.egAdd
    var shift: UInt8 = 0
    
    if nonZero {
      if rateHi < 12 {
        if slot.chip!.egState != 0 {
          switch egShift {
            case 12:
              shift = 1
              break
            case 13:
              shift = (rateLo >> 1) & 0x01
              break
            case 14:
              shift = rateLo & 0x01
              break
            default:
              break
          }
        }
      } else {
        shift = (rateHi & 0x03) + egIncStep[Int(rateLo)][Int(slot.chip!.egTimerLo)]
        
        if (shift & 0x04) != 0 {
          shift = 0x03
        }
        
        if shift == 0 {
          shift = slot.chip!.egState
        }
      }
    }
    
    var egRout: UInt16 = slot.egRout
    var egInc: Int16 = 0
    var egOff: UInt8 = 0
    
    // Instant attack
    if reset != 0 && rateHi == 0x0F {
      egRout = 0x00
    }
    
    // Envelope off
    if (slot.egRout & 0x1F8) == 0x1F8 {
      egOff = 1
    }
    
    if slot.egGen == .attack && reset == 0 && egOff != 0 {
      egRout = 0x1FF
    }
    
    switch slot.egGen {
      case .attack:
        if slot.egRout == 0 {
          slot.egGen = .decay
        } else if slot.key != 0 && shift > 0 && rateHi != 0x0F {
          egInc = Int16(~slot.egRout >> (4 - shift))
        }
        break
      case .decay:
        if (slot.egRout >> 4) == slot.regSl {
          slot.egGen = .sustain
        } else if egOff == 0 && reset == 0 && shift > 0 {
          egInc = 1 << (shift - 1)
        }
        break
      case .sustain, .release:
        if egOff == 0 && reset == 0 && shift > 0 {
          egInc = 1 << (shift - 1)
        }
        break
    }
    
    slot.egRout = UInt16((Int16(egRout) + egInc) & 0x1FF)
    
    // Key off
    if reset != 0 {
      slot.egGen = .attack
    }
    
    if slot.key == 0 {
      slot.egGen = .release
    }
  }
  
  
  private func envelopeKeyOn(_ slot: OPLSlot, _ type: OPLEnvelopeKeyType) {
    slot.key |= UInt8(type.rawValue)
  }
  
  
  private func envelopeKeyOff(_ slot: OPLSlot, _ type: OPLEnvelopeKeyType) {
    slot.key &= UInt8(~type.rawValue)
  }
  
  
// MARK: Phase generator
  
  private func phaseGenerate(_ slot: OPLSlot) {
    let chip = slot.chip!
    var fNum = slot.channel!.fNum
    
    if slot.regVib != 0 {
      var range = Int8((fNum >> 7) & 7)
      let vibpos = slot.chip!.vibpos
      
      if (vibpos & 3) == 0 {
        range = 0
      } else if (vibpos & 1) != 0 {
        range >>= 1
      }
      
      range >>= slot.chip!.vibshift
      
      if (vibpos & 4) != 0 {
        range = -range
      }
      
      fNum += UInt16(range)
    }
    
    let baseFreq = (fNum << slot.channel!.block) >> 1
    let phase = UInt16(slot.pgPhase >> 9)
    
    if slot.pgReset != 0 {
      slot.pgPhase = 0
    }
    
    slot.pgPhase += (UInt32(baseFreq) * UInt32(mt[Int(slot.regMult)])) >> 1
    
    let noise = chip.noise
    slot.pgPhaseOut = phase
    
    if slot.slotNum == 13 {
      chip.rmHhBit2 = UInt8((phase >> 2) & 1)
      chip.rmHhBit3 = UInt8((phase >> 3) & 1)
      chip.rmHhBit7 = UInt8((phase >> 7) & 1)
      chip.rmHhBit8 = UInt8((phase >> 8) & 1)
    }
    
    if slot.slotNum == 17 && (chip.rhy & 0x20) != 0 { /* tc */
      chip.rmTcBit3 = UInt8((phase >> 3) & 1)
      chip.rmTcBit5 = UInt8((phase >> 5) & 1)
    }
    
    if (chip.rhy & 0x20) != 0 {
      let rmXor = (chip.rmHhBit2 ^ chip.rmHhBit7)
        | (chip.rmHhBit3 ^ chip.rmTcBit5)
        | (chip.rmTcBit3 ^ chip.rmTcBit5)
      
      switch slot.slotNum {
        case 13: /* hh */
          slot.pgPhaseOut = UInt16(rmXor << 9)
          
          if (UInt32(rmXor) ^ (noise & 1)) != 0 {
            slot.pgPhaseOut |= 0xD0
          } else {
            slot.pgPhaseOut |= 0x34
          }
          
          break
        case 16: /* sd */
          slot.pgPhaseOut = UInt16((chip.rmHhBit8 << 9) | ((chip.rmHhBit8 ^ UInt8(noise & 1)) << 8))
          break
        case 17: /* tc */
          slot.pgPhaseOut = UInt16(rmXor << 9) | 0x80
          break
        default:
          break
      }
    }
    
    let nBit = ((noise >> 14) ^ noise) & 0x01
    chip.noise = (noise >> 1) | (nBit << 22)
  }
  
  
// MARK: Slots
  
  private func slotWrite20(_ slot: OPLSlot, data: UInt8) {
    if ((data >> 7) & 0x01) != 0 {
      withUnsafeMutablePointer(to: &(slot.chip!.tremolo)) {
        slot.trem = $0
      }
    } else {
      // Cast from UnsafeMutablePointer<Int16> to UnsafeMutablePointer<UInt8>
      withUnsafeMutablePointer(to: &slot.chip!.zeromod) {
        $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<Int16>.size) { ptr8 in
          slot.trem = ptr8
        }
      }
    }
  }
  
  
  private func slotWrite40(_ slot: OPLSlot, data: UInt8) {
    slot.regKsl = (data >> 6) & 0x03
    slot.regTl = data & 0x3F
    envelopeUpdateKSL(slot)
  }

  
  private func slotWrite60(_ slot: OPLSlot, data: UInt8) {
    slot.regAr = (data >> 4) & 0x0F
    slot.regDr = data & 0x0F
  }

  
  private func slotWrite80(_ slot: OPLSlot, data: UInt8) {
    slot.regSl = (data >> 4) & 0x0F
    
    if slot.regSl == 0x0F {
      slot.regSl = 0x1F
    }
    
    slot.regRr = data & 0x0F
  }
  
  
  private func slotWriteE0(_ slot: OPLSlot, data: UInt8) {
    slot.regWf = data & 0x07
    
    if slot.chip!.newm == 0 {
      slot.regWf &= 0x03
    }
  }
  
  
  private func slotGenerate(_ slot: OPLSlot) {
    let phase = slot.pgPhaseOut + UInt16(slot.mod!.pointee)
    let envelope = slot.egOut
    
    switch slot.regWf {
      case 0:
        slot.out = envelopeCalcSin0(phase, envelope)
        break
      case 1:
        slot.out = envelopeCalcSin1(phase, envelope)
        break
      case 2:
        slot.out = envelopeCalcSin2(phase, envelope)
        break
      case 3:
        slot.out = envelopeCalcSin3(phase, envelope)
        break
      case 4:
        slot.out = envelopeCalcSin4(phase, envelope)
        break
      case 5:
        slot.out = envelopeCalcSin5(phase, envelope)
        break
      case 6:
        slot.out = envelopeCalcSin6(phase, envelope)
        break
      case 7:
        slot.out = envelopeCalcSin7(phase, envelope)
        break
      default:
        break
    }
  }
  
  
  private func slotCalcFB(_ slot: OPLSlot) {
    if slot.channel!.fb != 0x00 {
      slot.fbMod = (slot.prOut + slot.out) >> (0x09 - slot.channel!.fb)
    } else {
      slot.fbMod = 0
    }
    
    slot.prOut = slot.out
  }
  
  
// MARK: - Channels
  
  private func channelUpdateRythm(_ chip: OPLChip, data: UInt8) {
    chip.rhy = data & 0x3F
    
    if (chip.rhy & 0x20) != 0 {
      let channel6 = chip.channel[6]
      let channel7 = chip.channel[7]
      let channel8 = chip.channel[8]
      
      withUnsafeMutablePointer(to: &(channel6.slotz[1].out)) {
        channel6.out[0] = $0
        channel6.out[1] = $0
      }

      withUnsafeMutablePointer(to: &(chip.zeromod)) {
        channel6.out[2] = $0
        channel6.out[3] = $0
      }

      withUnsafeMutablePointer(to: &(channel7.slotz[0].out)) {
        channel7.out[0] = $0
        channel7.out[1] = $0
      }

      withUnsafeMutablePointer(to: &(channel7.slotz[1].out)) {
        channel7.out[2] = $0
        channel7.out[3] = $0
      }

      withUnsafeMutablePointer(to: &(channel8.slotz[0].out)) {
        channel8.out[0] = $0
        channel8.out[1] = $0
      }
      
      withUnsafeMutablePointer(to: &(channel8.slotz[1].out)) {
        channel8.out[2] = $0
        channel8.out[3] = $0
      }

      var chNum = 6
      
      while chNum < 9 {
        chip.channel[chNum].chType = .channelDrum
        chNum += 1
      }
      
      channelSetupAlg(channel6)
      channelSetupAlg(channel7)
      channelSetupAlg(channel8)
      
      /* hh */
      if (chip.rhy & 0x01) != 0 {
        envelopeKeyOn(channel7.slotz[0], .drum)
      } else {
        envelopeKeyOff(channel8.slotz[0], .drum)
      }
      
      /* tc */
      if (chip.rhy & 0x02) != 0 {
        envelopeKeyOn(channel8.slotz[1], .drum)
      } else {
        envelopeKeyOff(channel8.slotz[1], .drum)
      }
      
      /* tom */
      if (chip.rhy & 0x04) != 0 {
        envelopeKeyOn(channel8.slotz[0], .drum)
      } else {
        envelopeKeyOff(channel8.slotz[0], .drum)
      }
      
      /* sd */
      if (chip.rhy & 0x08) != 0 {
        envelopeKeyOn(channel7.slotz[1], .drum)
      } else {
        envelopeKeyOff(channel7.slotz[1], .drum)
      }
      
      /* bd */
      if (chip.rhy & 0x10) != 0 {
        envelopeKeyOn(channel6.slotz[0], .drum)
        envelopeKeyOn(channel6.slotz[1], .drum)
      } else {
        envelopeKeyOff(channel6.slotz[0], .drum)
        envelopeKeyOff(channel6.slotz[1], .drum)
      }
    } else {
      var chNum = 6
      
      while chNum < 9 {
        chip.channel[chNum].chType = .channel2op
        channelSetupAlg(chip.channel[chNum])
        envelopeKeyOff(chip.channel[chNum].slotz[0], .drum)
        envelopeKeyOff(chip.channel[chNum].slotz[1], .drum)
        chNum += 1
      }
    }
  }
  
  
  private func channelWriteA0(_ channel: OPLChannel, data: UInt8) {
    if channel.chip!.newm != 0 && channel.chType == .channel4op2 {
      return
    }
    
    channel.fNum = (channel.fNum & 0x300) | UInt16(data)
    channel.ksv = (channel.block << 1) | UInt8((channel.fNum >> (0x09 - channel.chip!.nts)) & 0x01)
    
    envelopeUpdateKSL(channel.slotz[0])
    envelopeUpdateKSL(channel.slotz[1])
    
    if channel.chip!.newm != 0 && channel.chType == .channel4op {
      channel.pair!.fNum = channel.fNum
      channel.pair!.ksv = channel.ksv
      
      envelopeUpdateKSL(channel.pair!.slotz[0])
      envelopeUpdateKSL(channel.pair!.slotz[1])
    }
  }
  
  
  private func channelWriteB0(_ channel: OPLChannel, data: UInt8) {
    if channel.chip!.newm != 0 && channel.chType == .channel4op2 {
      return
    }
    
    channel.fNum = (channel.fNum & 0xFF) | UInt16((data & 0x03) << 8)
    channel.block = (data >> 2) & 0x07
    channel.ksv = (channel.block << 1) | UInt8((channel.fNum >> (0x09 - channel.chip!.nts)) & 0x01)
     
    envelopeUpdateKSL(channel.slotz[0])
    envelopeUpdateKSL(channel.slotz[1])
    
    if channel.chip!.newm != 0 && channel.chType == .channel4op {
      channel.pair!.fNum = channel.fNum
      channel.pair!.block = channel.block
      channel.pair!.ksv = channel.ksv
      
      envelopeUpdateKSL(channel.pair!.slotz[0])
      envelopeUpdateKSL(channel.pair!.slotz[1])
    }
  }
  
  
  private func channelSetupAlg(_ channel: OPLChannel) {
    if channel.chType == .channelDrum {
      if channel.chNum == 7 || channel.chNum == 8 {
        withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
          channel.slotz[0].mod = $0
          channel.slotz[1].mod = $0
        }
        return
      }
      
      switch (channel.alg & 0x01) {
        case 0x00:
          withUnsafeMutablePointer(to: &channel.slotz[0].fbMod) {
            channel.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[1].out) {
            channel.slotz[1].mod = $0
          }
          break
        case 0x01:
          withUnsafeMutablePointer(to: &channel.slotz[0].fbMod) {
            channel.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.slotz[1].mod = $0
          }
          break
        default:
          break
      }
    }
    
    if (channel.alg & 0x08) != 0 {
      return
    }
    
    if (channel.alg & 0x04) != 0 {
      withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
        channel.pair!.out[0] = $0
        channel.pair!.out[1] = $0
        channel.pair!.out[2] = $0
        channel.pair!.out[3] = $0
      }
      
      switch (channel.alg & 0x03) {
        case 0x00:
          withUnsafeMutablePointer(to: &channel.pair!.slotz[0].fbMod) {
            channel.pair!.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.pair!.slotz[0].out) {
            channel.pair!.slotz[1].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.pair!.slotz[1].out) {
            channel.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[0].out) {
            channel.slotz[1].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[1].out) {
            channel.out[0] = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.out[1] = $0
            channel.out[2] = $0
            channel.out[3] = $0
          }
          break
        case 0x01:
          withUnsafeMutablePointer(to: &channel.pair!.slotz[0].fbMod) {
            channel.pair!.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.pair!.slotz[0].out) {
            channel.pair!.slotz[1].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[0].out) {
            channel.slotz[1].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.pair!.slotz[1].out) {
            channel.out[0] = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[1].out) {
            channel.out[1] = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.out[2] = $0
            channel.out[3] = $0
          }
          break
        case 0x02:
          withUnsafeMutablePointer(to: &channel.pair!.slotz[0].fbMod) {
            channel.pair!.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.pair!.slotz[1].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.pair!.slotz[1].out) {
            channel.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[0].out) {
            channel.slotz[1].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.pair!.slotz[0].out) {
            channel.out[0] = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[1].out) {
            channel.out[1] = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.out[2] = $0
            channel.out[3] = $0
          }
          break
        case 0x03:
          withUnsafeMutablePointer(to: &channel.pair!.slotz[0].fbMod) {
            channel.pair!.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.pair!.slotz[1].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.pair!.slotz[1].out) {
            channel.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.slotz[1].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.pair!.slotz[0].out) {
            channel.out[0] = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[0].out) {
            channel.out[1] = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[1].out) {
            channel.out[2] = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.out[3] = $0
          }
          break
        default:
          break
      }
    } else {
      switch (channel.alg & 0x01) {
        case 0x00:
          withUnsafeMutablePointer(to: &channel.slotz[0].fbMod) {
            channel.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[0].out) {
            channel.slotz[1].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[1].out) {
            channel.out[0] = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.out[1] = $0
            channel.out[2] = $0
            channel.out[3] = $0
          }
          break
        case 0x01:
          withUnsafeMutablePointer(to: &channel.slotz[0].fbMod) {
            channel.slotz[0].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.slotz[1].mod = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[0].out) {
            channel.out[0] = $0
          }
          withUnsafeMutablePointer(to: &channel.slotz[1].out) {
            channel.out[1] = $0
          }
          withUnsafeMutablePointer(to: &channel.chip!.zeromod) {
            channel.out[2] = $0
            channel.out[3] = $0
          }
          break
        default:
          break
      }
    }
  }
  
  
  private func channelUpdateAlg(_ channel: OPLChannel) {
    channel.alg = channel.con
    
    if channel.chip?.newm != 0 {
      if channel.chType == .channel4op {
        channel.pair!.alg = 0x04 | (channel.con << 1) | channel.pair!.con
        channel.alg = 0x08
        
        channelSetupAlg(channel)
      } else if channel.chType == .channel4op2 {
        channel.alg = 0x04 | (channel.pair!.con << 1) | channel.con
        channel.pair!.alg = 0x08
        
        channelSetupAlg(channel)
      } else {
        channelSetupAlg(channel)
      }
    } else {
      channelSetupAlg(channel)
    }
  }

  
  private func channelWriteC0(_ channel: OPLChannel, data: UInt8) {
    channel.fb = (data & 0x0E) >> 1
    channel.con = data & 0x01
    channelUpdateAlg(channel)
    
    if channel.chip!.newm != 0 {
      channel.cha = ((data >> 4) & 0x01) != 0 ? ~0 : 0
      channel.chb = ((data >> 5) & 0x01) != 0 ? ~0 : 0
      channel.chc = ((data >> 6) & 0x01) != 0 ? ~0 : 0
      channel.chd = ((data >> 7) & 0x01) != 0 ? ~0 : 0
    } else {
      channel.cha = UInt16(~0)
      channel.chb = UInt16(~0)
      // TODO: Verify on real chip if DAC2 output is disabled in compat mode
      channel.chc = UInt16(0)
      channel.chd = UInt16(0)
    }
    
#if OPL_ENABLE_STEREOEXT
    if channel.chip?.stereoext == 0 {
      channel.leftPan = channel.cha << 16
      channel.rightPan = channel.chb << 16
    }
#endif
  }

  
#if OPL_ENABLE_STEREOEXT
  private func channelWriteD0(_ channel: OPLChannel, data: UInt8) {
    if channel.chip?.stereoext != 0 {
      channel.leftPan = panpotLUT[data ^ 0xFF]
      channel.rightPan = panpotLUT[data]
    }
  }
#endif

  
  private func channelKeyOn(_ channel: OPLChannel) {
    if channel.chip?.newm != 0 {
      if channel.chType == .channel4op {
        envelopeKeyOn(channel.slotz[0], .normal)
        envelopeKeyOn(channel.slotz[1], .normal)
        envelopeKeyOn(channel.pair!.slotz[0], .normal)
        envelopeKeyOn(channel.pair!.slotz[1], .normal)
      } else if channel.chType == .channel4op2 || channel.chType == .channelDrum {
        envelopeKeyOn(channel.slotz[0], .normal)
        envelopeKeyOn(channel.slotz[1], .normal)
      }
    } else {
      envelopeKeyOn(channel.slotz[0], .normal)
      envelopeKeyOn(channel.slotz[1], .normal)
    }
  }

  
  private func channelKeyOff(_ channel: OPLChannel) {
    if channel.chip?.newm != 0 {
      if channel.chType == .channel4op {
        envelopeKeyOff(channel.slotz[0], .normal)
        envelopeKeyOff(channel.slotz[1], .normal)
        envelopeKeyOff(channel.pair!.slotz[0], .normal)
        envelopeKeyOff(channel.pair!.slotz[1], .normal)
      } else if channel.chType == .channel4op2 || channel.chType == .channelDrum {
        envelopeKeyOff(channel.slotz[0], .normal)
        envelopeKeyOff(channel.slotz[1], .normal)
      }
    } else {
      envelopeKeyOff(channel.slotz[0], .normal)
      envelopeKeyOff(channel.slotz[1], .normal)
    }
  }

  
  private func channelSet4Op(_ chip: OPLChip, data: UInt8) {
    var bit = 0
    var chNum = 0
    
    while bit < 6 {
      chNum = bit
      
      if bit >= 3 {
        chNum += 9 - 3
      }
      
      if ((data >> bit) & 0x01) != 0 {
        chip.channel[chNum].chType = .channel4op
        chip.channel[chNum + 3].chType = .channel4op2
        channelUpdateAlg(chip.channel[chNum])
      } else {
        chip.channel[chNum].chType = .channel2op
        chip.channel[chNum + 3].chType = .channel2op
        channelUpdateAlg(chip.channel[chNum])
        channelUpdateAlg(chip.channel[chNum + 3])
      }

      bit += 1
    }
  }

  
  private func clipSample(_ sample: Int32) -> Int16 {
    if (sample > 32767) {
      return 32767
    } else if (sample < -32768) {
      return -32768
    }
    
    return Int16(truncatingIfNeeded: sample)
  }
  
  
  private func processSlot(_ slot: OPLSlot) {
    self.slotCalcFB(slot)
    self.envelopeCalc(slot)
    self.phaseGenerate(slot)
    self.slotGenerate(slot)
  }
  
  
  /* inline void OPL3_Generate4Ch(opl3_chip *chip, int16_t *buf4) */
  private func generate4Ch(_ chip: OPLChip, _ buf4: inout [Int16]) {
    var mix = [Int32](repeating: 0, count: 2)
    var accm: Int16 = 0
    var shift: UInt8 = 0
    var out = [UnsafeMutablePointer<Int16>?](repeating: nil, count: 4)
    
    buf4[1] = clipSample(chip.mixbuff[1])
    buf4[3] = clipSample(chip.mixbuff[3])
    
    var ii = 0

    /*
     #if OPL_QUIRK_CHANNELSAMPLEDELAY
      for (ii = 0; ii < 15; ii++)
     #else
      for (ii = 0; ii < 36; ii++)
     #endif
     */
    
    while ii < 36 {
      processSlot(chip.slot[ii])
      ii += 1
    }

    ii = 0
    
    while ii < 18 {
      var channel = chip.channel[ii]
      out = channel.out
      accm = out[0]!.pointee + out[1]!.pointee + out[2]!.pointee + out[3]!.pointee
#if OPL_ENABLE_STEREOEXT
      mix[0] += (Int32(accm) * channel.leftPan) >> 16
#else
      mix[0] += Int32(accm & Int16(channel.cha))
#endif
      mix[1] += Int32(accm & Int16(channel.chc))
      ii += 1
    }
    
    chip.mixbuff[0] = mix[0]
    chip.mixbuff[2] = mix[2]
    
    buf4[0] = clipSample(chip.mixbuff[0])
    buf4[2] = clipSample(chip.mixbuff[2])
    
    mix[0] = 0
    mix[1] = 0
    
    ii = 0
    
    while ii < 18 {
      var channel = chip.channel[ii]
      out = channel.out
      accm = out[0]!.pointee + out[1]!.pointee + out[2]!.pointee + out[3]!.pointee
#if OPL_ENABLE_STEREOEXT
      mix[0] += (Int32(accm) * channel.rightPan) >> 16
#else
      mix[0] += Int32(accm & Int16(channel.chb))
#endif
      mix[1] += Int32(accm & Int16(channel.chd))
      ii += 1
    }
    
    if (chip.timer & 0x3F) == 0x3F {
      chip.tremolopos = (chip.tremolopos + 1) % 210
    }
    
    if chip.tremolopos < 105 {
      chip.tremolo = chip.tremolopos >> chip.tremoloshift
    } else {
      chip.tremolo = (210 - chip.tremolopos) >> chip.tremoloshift
    }
    
    if (chip.timer & 0x3FF) == 0x3FF {
      chip.vibpos = (chip.vibpos + 1) & 7
    }
    
    chip.timer += 1
    
    if chip.egState != 0 {
      while shift < 13 && ((chip.egTimer >> shift) & 1) == 0 {
        shift += 1
      }
      
      if shift > 12 {
        chip.egAdd = 0
      } else {
        chip.egAdd = shift + 1
      }
      
      if chip.egTimerRem != 0 || chip.egState != 0 {
        if chip.egTimer == 0xFFFFFFFFF {
          chip.egTimer = 0
          chip.egTimerRem = 1
        } else {
          chip.egTimer += 1
          chip.egTimerRem = 0
        }
      }
      
      chip.egState ^= 1
      
      var writebuf = chip.writebuf[Int(chip.writebufCur)]
      
      while writebuf.time <= chip.writebufSampleCnt {
        if (writebuf.reg & 0x200) == 0 {
          break
        }
        
        writebuf.reg &= 0x1ff
        
        writeReg(chip, writebuf.reg, writebuf.data)
        chip.writebufCur = (chip.writebufCur + 1) % UInt32(oplWritebufSize)
        
        writebuf = chip.writebuf[Int(chip.writebufCur)]
      }
      
      chip.writebufSampleCnt += 1
    }
  }
  
  
  /* void OPL3_Generate(opl3_chip *chip, int16_t *buf) */
  public func generate(_ chip: OPLChip, _ buf: inout [Int16]) {
    var samples = [Int16](repeating: 0, count: 4)
    generate4Ch(chip, &samples)
    buf[0] = samples[0]
    buf[1] = samples[1]
  }
  
  
  /* void OPL3_Generate4ChResampled(opl3_chip *chip, int16_t *buf4) */
  public func generate4ChResampled(_ chip: OPLChip, _ buf4: inout [Int16], _ sndPtrIndex: Int = 0) {
    while chip.samplecnt >= chip.rateratio {
      chip.oldsamples[0] = chip.samples[0]
      chip.oldsamples[1] = chip.samples[1]
      chip.oldsamples[2] = chip.samples[2]
      chip.oldsamples[3] = chip.samples[3]
      generate4Ch(chip, &chip.samples)
      chip.samplecnt -= chip.rateratio
    }
    
    buf4[sndPtrIndex + 0] = Int16((Int32(chip.oldsamples[0]) * (chip.rateratio - chip.samplecnt) + Int32(chip.samples[0]) * chip.samplecnt) / chip.rateratio)
    buf4[sndPtrIndex + 1] = Int16((Int32(chip.oldsamples[1]) * (chip.rateratio - chip.samplecnt) + Int32(chip.samples[1]) * chip.samplecnt) / chip.rateratio)
    buf4[sndPtrIndex + 2] = Int16((Int32(chip.oldsamples[2]) * (chip.rateratio - chip.samplecnt) + Int32(chip.samples[2]) * chip.samplecnt) / chip.rateratio)
    buf4[sndPtrIndex + 3] = Int16((Int32(chip.oldsamples[3]) * (chip.rateratio - chip.samplecnt) + Int32(chip.samples[3]) * chip.samplecnt) / chip.rateratio)
    
    chip.samplecnt += 1 << rsmFrac
  }
  
  
  /* void OPL3_GenerateResampled(opl3_chip *chip, int16_t *buf) */
  public func generateResampled(_ chip: OPLChip, _ buf: inout [Int16], _ sndPtrIndex: Int) {
    var samples = [Int16](repeating: 0, count: 4)
    generate4ChResampled(chip, &samples)
    buf[sndPtrIndex + 0] = samples[0]
    buf[sndPtrIndex + 1] = samples[1]
  }
  
  
  /* void OPL3_Reset(opl3_chip *chip, uint32_t samplerate) */
  public func reset(_ chip: OPLChip, _ samplerate: UInt32) {
    var slotNum: UInt8 = 0
    var chanNum: UInt8 = 0
    var localChSlot: UInt8 = 0
    
    // memset(chip, 0, sizeof(opl3_chip));
    
    while slotNum < 36 {
      let slot = chip.slot[Int(slotNum)]
      slot.chip = chip
      slot.egRout = 0x1FF
      slot.egOut = 0x1FF
      slot.egGen = OPLEnvelopeGenNumber.release

      withUnsafeMutablePointer(to: &chip.zeromod) { ptr in
        slot.mod = ptr
        
        // Cast from UnsafeMutablePointer<Int16> to UnsafeMutablePointer<UInt8>
        ptr.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<Int16>.size) { ptr8 in
          slot.trem = ptr8
        }
      }

      slot.slotNum = slotNum
      slotNum += 1
    }
    
    while chanNum < 18 {
      var channel = chip.channel[Int(chanNum)]
      localChSlot = chSlot[Int(chanNum)]
      
      channel.slotz[0] = chip.slot[Int(localChSlot)]
      channel.slotz[1] = chip.slot[Int(localChSlot + 3)]
      chip.slot[Int(localChSlot)].channel = channel
      chip.slot[Int(localChSlot + 3)].channel = channel
      
      if (chanNum % 9) < 3 {
        channel.pair = chip.channel[Int(chanNum + 3)]
      } else if (chanNum % 9) < 6 {
        channel.pair = chip.channel[Int(chanNum - 3)]
      }
      
      channel.chip = chip
      
      withUnsafeMutablePointer(to: &chip.zeromod) {
        channel.out[0] = $0
        channel.out[1] = $0
        channel.out[2] = $0
        channel.out[3] = $0
      }
      
      channel.chType = OPLChannelType.channel2op
      channel.cha = 0xFFFF
      channel.chb = 0xFFFF
#if OPL_ENABLE_STEREOEXT
      channel.leftPan = 0x10000
      channel.rightPan = 0x10000
#endif
      channel.chNum = chanNum
      channelSetupAlg(channel)
      
      chanNum += 1
    }

    chip.noise = 1
    chip.rateratio = Int32((samplerate << rsmFrac) / 49716)
    chip.tremoloshift = 4
    chip.vibshift = 1

#if OPL_ENABLE_STEREOEXT
    if panpotLUTBuild == 0 {
      var i = 0
      
      while i < 256 {
        panpotLUT[i] = OPL3.oplSin(Double(i))
      }
      
      panpotLUTBuild = 1
    }
#endif
  }
  
  
  /* void OPL3_WriteReg(opl3_chip *chip, uint16_t reg, uint8_t v) */
  public func writeReg(_ chip: OPLChip, _ reg: UInt16, _ v: UInt8) {
    let high = UInt8((reg >> 8) & 0x01)
    let regm = UInt8(reg & 0xFF)
    
    let adSlotValue = adSlot[Int(regm & 0x1F)]
    let adSlotIndex = 18 * Int(high) + Int(adSlotValue)
    let channelIndex = 9 * Int(high) + Int(regm & 0x0F)
    
    
    switch regm & 0xF0 {
      case 0x00:
        if high > 0 {
          switch regm & 0x0F {
            case 0x04:
              self.channelSet4Op(chip, data: v)
              break
            case 0x05:
#if OPL_ENABLE_STEREOEXT
              chip.stereoext = (v >> 1) & 0x01
#endif
              break
            default:
              break
          }
        } else {
          switch regm & 0x0F {
            case 0x08:
              chip.nts = (v >> 6) & 0x01
              break
            default:
              break
          }
        }
        
        break
      case 0x20, 0x30:
        if adSlotValue >= 0 {
          slotWrite20(chip.slot[adSlotIndex], data: v)
        }
        
        break
      case 0x40, 0x50:
        if adSlotValue >= 0 {
          slotWrite40(chip.slot[adSlotIndex], data: v)
        }
        
        break
      case 0x60, 0x70:
        if adSlotValue >= 0 {
          slotWrite60(chip.slot[adSlotIndex], data: v)
        }
        
        break
      case 0x80, 0x90:
        if adSlotValue >= 0 {
          slotWrite80(chip.slot[adSlotIndex], data: v)
        }
        
        break
      case 0xE0, 0xF0:
        if adSlotValue >= 0 {
          slotWriteE0(chip.slot[adSlotIndex], data: v)
        }
        
        break
      case 0xA0:
        if (regm & 0x0F) < 9 {
          channelWriteA0(chip.channel[channelIndex], data: v)
        }
        
        break
      case 0xB0:
        if regm == 0xBD && high == 0 {
          chip.tremoloshift = (((v >> 7) ^ 1) << 1) + 2
          chip.vibshift = ((v >> 6) & 0x01) ^ 1
          channelUpdateRythm(chip, data: v)
        } else if (regm & 0x0F) < 9 {
          channelWriteB0(chip.channel[channelIndex], data: v)
          
          if (v & 0x20) != 0 {
            channelKeyOn(chip.channel[channelIndex])
          } else {
            channelKeyOff(chip.channel[channelIndex])
          }
        }
        
        break
      case 0xC0:
        if (regm & 0x0F) < 9 {
          channelWriteC0(chip.channel[channelIndex], data: v)
        }
        
        break
#if OPL_ENABLE_STEREOEXT
      case 0xD0:
        if (regm & 0x0F) < 9 {
          channelWriteD0(chip.channel[channelIndex], data: v)
        }
        
        break
#endif
      default:
        break
    }
  }
  
  
  /* void OPL3_WriteRegBuffered(opl3_chip *chip, uint16_t reg, uint8_t v) */
  public func writeRegBuffered(_ chip: OPLChip, _ reg: UInt16, _ v: UInt8) {
    var time1: UInt64 = 0
    var time2: UInt64 = 0
    var writebufLast: UInt32 = 0
    var writebuf = OPLWriteBuffer()

    writebufLast = chip.writebufLast
    writebuf = chip.writebuf[Int(writebufLast)]
    
    if writebuf.reg & 0x200 != 0 {
      self.writeReg(chip, writebuf.reg & 0x1ff, writebuf.data)
      
      chip.writebufCur = (writebufLast + 1) % UInt32(writebuf.data)
      chip.writebufSampleCnt = writebuf.time
    }
    
    writebuf.reg = reg | 0x200
    writebuf.data = v
    time1 = chip.writebufLastTime + UInt64(oplWritebufDelay)
    time2 = chip.writebufSampleCnt
    
    if time1 < time2 {
      time1 = time2
    }
    
    writebuf.time = time1
    chip.writebufLastTime = time1
    chip.writebufLast = (writebufLast + 1) % UInt32(writebuf.data)
  }
  
  
  /* void OPL3_Generate4ChStream(opl3_chip *chip, int16_t *sndptr1, int16_t *sndptr2, uint32_t numsamples) */
  public func generate4ChStream(_ chip: OPLChip, _ sndptr1: inout [Int16], _ sndptr2: inout [Int16], _ numsamples: UInt32) {
    var n = 0
    var i: UInt32 = 0
    var samples = Array.init(repeating: Int16.zero, count: 4)
    
    while i < numsamples {
      generate4ChResampled(chip, &samples)
      sndptr1[n + 0] = samples[0]
      sndptr1[n + 1] = samples[1]
      sndptr2[n + 0] = samples[2]
      sndptr2[n + 1] = samples[3]
      // n = sndptr1, sndptr2 increments
      n += 2
      i += 1
    }
  }
  
  
  /* void OPL3_GenerateStream(opl3_chip *chip, int16_t *sndptr, uint32_t numsamples) */
  public func generateStream(_ chip: OPLChip, _ sndptr: inout [Int16], _ numsamples: UInt32) {
    var n = 0
    var i: UInt32 = 0

    while i < numsamples {
      generateResampled(chip, &sndptr, n)
      n += 2 // sndptr += 2
      i += 1
    }
  }
}
