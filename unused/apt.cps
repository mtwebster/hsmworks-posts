/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Common APT ISO 4343 post processor configuration.

  $Revision: 25357 $
  $Date: 2011-05-10 14:35:27 +0200 (ti, 10 maj 2011) $
  
  FORKID {1E3EF622-47FE-487d-937B-07920048EF52}
*/

description = "Common ISO 4343 APT";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;

unit = ORIGINAL_UNIT; // do not map unit
extension = "apt";
setCodePage("ansi");

allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

// collected state
var currentFeed;
var feedUnit;
var coolantActive = false;
var radiusCompensationActive = false;

function writeComment(text) {
  writeln("PPRINT/'" + filterText(text, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789(.,)/-+*= \t") + "'");
}

function onOpen() {
  var machineId = machineConfiguration.getModel();
  writeln("MACHIN/" + machineId);
  writeln("MODE/" + (isMilling() ? "MILL" : "TURN")); // first statement for an operation
  writeln("PARTNO/'" + programName + "'");
  writeComment(programName);
  writeComment(programComment);
}

function onComment(comment) {
  writeComment(comment);
}

var mapCommand = {
  COMMAND_STOP:"STOP",
  COMMAND_OPTIONAL_STOP:"OPSTOP",
  COMMAND_STOP_SPINDLE:"SPINDL/ON",
  COMMAND_START_SPINDLE:"SPINDL/OFF",

  // COMMAND_ORIENTATE_SPINDLE
  
  COMMAND_SPINDLE_CLOCKWISE:"SPINDL/CLW",
  COMMAND_SPINDLE_COUNTERCLOCKWISE:"SPINDL/CCLW"
  
  // COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION
  // COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION
};

function onCommand(command) {
  switch (command) {
  case COMMAND_LOCK_MULTI_AXIS:
    return;
  case COMMAND_UNLOCK_MULTI_AXIS:
    return;
  case COMMAND_BREAK_CONTROL:
    return;
  case COMMAND_TOOL_MEASURE:
    return;
  }

  if (mapCommand[command]) {
    writeln(mapCommand[command]);
  } else {
    warning("Unsupported command: " + getCommandStringId(command));
    writeComment("Unsupported command: " + getCommandStringId(command));
  }
}

function onCoolant() {
  if (coolant == COOLANT_OFF) {
    if (coolantActive) {
      writeln("COOLNT/OFF");
      coolantActive = false;
    }
  } else {
    if (!coolantActive) {
      writeln("COOLNT/ON");
      coolantActive = true;
    }

    var mapCoolant = {COOLANT_FLOOD:"flood", COOLANT_MIST:"MIST", COOLANT_TOOL:"THRU"};
    if (mapCoolant[coolant]) {
      writeln("COOLNT/" + mapCoolant[coolant]);
    } else {
      warning("Unsupported coolant mode: " + coolant);
      writeComment("Unsupported coolant mode: " + coolant);
    }
  }
}

function onSection() {
  writeln("UNITS/" + ((currentSection.getUnit() == IN) ? "INCHES" : "MM"));
  feedUnit = (currentSection.getUnit() == IN) ? "IPM" : "MMPM";

  if (currentSection.isMultiAxis()) {
    writeln("MULTAX/ON");
  } else {
    writeln("MULTAX/OFF");
  }

  var d = tool.diameter;
  var r = tool.cornerRadius;
  var e = 0;
  var f = 0;
  var a = 0;
  var b = 0;
  var h = tool.bodyLength;
  writeln("CUTTER/" + d + ", " + r + ", " + e + ", " + f + ", " + a + ", " + b + ", " + h);

  var t = tool.number;
  var p = 0;
  var l = tool.bodyLength;
  var o = tool.lengthOffset;
  writeln("LOADTL/" + t + ", " + p + ", " + l + ", " + o);
  // writeln("OFSTNO/" + 0); // not used

  if (isMilling()) {
    writeln("SPINDL/" + Math.abs(tool.spindleRPM) + ", RPM, " + ((tool.spindleRPM >= 0) ? "CLW" : "CCLW"));
  }
  
  if (isTurning()) {
    writeln(
      "SPINDL/" + Math.abs(tool.spindleRPM) + ", " + ((unit == IN) ? "SFM" : "SMM") + ", " + ((tool.spindleRPM >= 0) ? "CLW" : "CCLW")
    );
  }
  
  // writeln("ORIGIN/" + currentSection.workOrigin.x + ", " + currentSection.workOrigin.y + ", " + currentSection.workOrigin.z);
}

function onDwell(time) {
  writeln("DELAY/" + time); // in seconds
}

function onRadiusCompensation() {
  if (radiusCompensation == RADIUS_COMPENSATION_OFF) {
    if (radiusCompensationActive) {
      radiusCompensationActive = false;
      writeln("CUTCOM/OFF");
    }
  } else {
    if (!radiusCompensationActive) {
      radiusCompensationActive = true;
      writeln("CUTCOM/ON");
    }
    var direction = (radiusCompensation == RADIUS_COMPENSATION_LEFT) ? "LEFT" : "RIGHT";
    if (tool.diameterOffset != 0) {
      writeln("CUTCOM/" + direction + ", " + tool.diameterOffset);
    } else {
      writeln("CUTCOM/" + direction);
    }
  }
}

function onRapid(x, y, z) {
  writeln("RAPID");
  writeln("GOTO/" + x + ", " + y + ", " + z);
}

function onLinear(x, y, z, feed) {
  if (feed != currentFeed) {
    currentFeed = feed;
    writeln("FEDRAT/" + feed + ", " + feedUnit);
  }
  writeln("GOTO/" + x + ", " + y + ", " + z);
}

function onRapid5D(x, y, z, dx, dy, dz) {
  writeln("RAPID");
  writeln("GOTO/" + x + ", " + y + ", " + z + ", " + dx + ", " + dy + ", " + dz);
}

function onLinear5D(x, y, z, dx, dy, dz, feed) {
  if (feed != currentFeed) {
    currentFeed = feed;
    writeln("FEDRAT/" + feed + ", " + feedUnit);
  }
  writeln("GOTO/" + x + ", " + y + ", " + z + ", " + dx + ", " + dy + ", " + dz);
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (feed != currentFeed) {
    currentFeed = feed;
    writeln("FEDRAT/" + feed + ", " + feedUnit);
  }

  var n = getCircularNormal();
  writeln(
    "MOVARC/" + cx + ", " + cy + ", " + cz + ", " + n.x + ", " + n.y + ", " + n.z + ", " + getCircularRadius() + ", ANGLE, " + (toDeg(getCircularSweep()))
  );
  writeln("GOTO/" + x + ", " + y + ", " + z);
}

function onCycle() {
  var d = cycle.depth;
  var f = cycle.feedrate;
  var c = cycle.clearance;
  var r = c - cycle.retract;
  var q = cycle.dwell;
  var i = cycle.incrementalDepth; // for pecking
  
  var statement;
  
  switch (cycleType) {
  case "drilling":
    statement = "CYCLE/DRILL, " + d + ", " + feedUnit + ", " + f + ", " + c;
    if (r > 0) {
      statement += ", RAPTO, " + r;
    }
    break;
  case "counter-boring":
    statement = "CYCLE/DRILL, " + d + ", " + feedUnit + ", " + f + ", " + c;
    if (r > 0) {
      statement += ", RAPTO, " + r;
    }
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "reaming":
    statement = "CYCLE/REAM, " + d + ", " + feedUnit + ", " + f + ", " + c;
    if (r > 0) {
      statement += ", RAPTO, " + r;
    }
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "boring":
    statement = "CYCLE/BORE, " + d + ", " + feedUnit + ", " + f + ", " + c;
    if (r > 0) {
      statement += ", RAPTO, " + r;
    }
    statement += ", ORIANT, " + 0; // unknown orientation
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "fine-boring":
    statement = "CYCLE/BORE, " + d + ", " + feedUnit + ", " + f + ", " + c + ", " + cycle.shift;
    if (r > 0) {
      statement += ", RAPTO, " + r;
    }
    statement += ", ORIANT, " + 0; // unknown orientation
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "deep-drilling":
    statement = "CYCLE/DEEP, " + d + ", INCR, " + i + ", " + feedUnit + ", " + f + ", " + c;
    if (r > 0) {
      statement += ", RAPTO, " + r;
    }
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "chip-breaking":
    statement = "CYCLE/BRKCHP, " + d + ", INCR, " + i + ", " + feedUnit + ", " + f + ", " + c;
    if (r > 0) {
      statement += ", RAPTO, " + r;
    }
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "tapping":
    if (tool.type == TOOL_TAP_LEFT_HAND) {
      cycleNotSupported();
    } else {
      statement = "CYCLE/TAP, " + d + ", " + feedUnit + ", " + f + ", " + c;
      if (r > 0) {
        statement += ", RAPTO, " + r;
      }
    }
    break;
  case "right-tapping":
    statement = "CYCLE/TAP, " + d + ", " + feedUnit + ", " + f + ", " + c;
    if (r > 0) {
      statement += ", RAPTO, " + r;
    }
    break;
  default:
    cycleNotSupported();
  }
  writeln(statement);
}

function onCyclePoint(x, y, z) {
  writeln("FEDRAT/" + cycle.feedrate + ", " + feedUnit);
  writeln("GOTO/" + x + ", " + y + ", " + z);
}

function onCycleEnd() {
  writeln("CYCLE/OFF");
}

function onSectionEnd() {
}

function onClose() {
  if (coolantActive) {
    coolantActive = false;
    writeln("COOLNT/OFF");
  }
  writeln("END");
  writeln("FINI");
}
