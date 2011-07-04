/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Generative Machining APT post processor configuration.

  $Revision: 25357 $
  $Date: 2011-05-10 14:35:27 +0200 (ti, 10 maj 2011) $
  
  FORKID {CCD0BC6D-B3F5-48cc-9C89-FA954D4BACE0}
*/

description = "Generative Machining APT";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;

unit = ORIGINAL_UNIT; // do not map unit
extension = "apt";
setCodePage("ansi");

// user-defined properties
properties = {
  optionalStop: true, // optional stop
  goHome: true // add GOHOME at end of file
};

allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion



var xyzFormat = createFormat({decimals:6}); // spacial
var aFormat = createFormat({decimals:6, scale:DEG}); // angle
var feedFormat = createFormat({decimals:1}); // feed
var rpmFormat = createFormat({decimals:0}); // spindle speed
var secFormat = createFormat({decimals:3}); // time

// collected state
var feedUnit;
var radiusCompensationActive = false;
var previousFeed;

/* Returns the specified string without any invalid characters. */
function toNiceString(text) {
  return filterText(translateText(text, ":", "."), "[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789(.,)/-+*= \t]").substr(0, 73);
}

function writeComment(text) {
  writeln("PPRINT/'" + toNiceString(text) + "'");
}

function onOpen() {
  writeln("PARTNO/'" + toNiceString(programName) + "'");

  var firstSection = getSection(0);
  writeln("UNITS/" + ((firstSection.getUnit() == IN) ? "INCHES" : "MM"));
  feedUnit = (firstSection.getUnit() == IN) ? "IPM" : "MMPM";
  unit = firstSection.getUnit(); // use unit of first section for all sections

  writeComment(programComment);

  var machineId = machineConfiguration.getModel();
  if (machineId) {
    writeln("MACHIN/" + machineId);
  }
}

function onComment(comment) {
  writeComment(comment);
}

var mapCommand = {
  COMMAND_STOP:"STOP",
  COMMAND_OPTIONAL_STOP:"OPSTOP",
  COMMAND_STOP_SPINDLE:"SPINDL/ON",
  COMMAND_START_SPINDLE:"SPINDL/OFF",
  COMMAND_SPINDLE_CLOCKWISE:"SPINDL/CLW",
  COMMAND_SPINDLE_COUNTERCLOCKWISE:"SPINDL/CCLW"
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

  if (!mapCommand[command]) {
    warning("Unsupported command: " + getCommandStringId(command));
    writeComment("Unsupported command: " + getCommandStringId(command));
  } else {
    writeln(mapCommand[command]);
  }
}

function onMachineCommand(command) {
  writeln("AUXFUN/" + command);
}

function onSection() {
  writeln("MODE/" + isMilling() ? "MILL" : "TURN"); // first statement for an operation
  // writeComment(...); // operation comment

  if (isTurning()) {
    writeln("HEAD/1");
  }

  if (machineConfiguration.hasHomePositionX() && machineConfiguration.hasHomePositionY()) {
    writeln(
      "FROM/" + xyzFormat.format(machineConfiguration.getHomePositionX()) + ", " +
      xyzFormat.format(machineConfiguration.getHomePositionY()) + ", " +
      xyzFormat.format(machineConfiguration.getRetractPlane())
    );
  }

  if (properties.optionalStop) {
    writeln("OPSTOP");
  }

  var t = tool.number;
  var p = 0;
  var l = tool.bodyLength;
  var o = tool.lengthOffset;
  writeln("LOADTL/" + t + ", IN, " + p + ", LENGTH, " + l + ", OSETNO, " + o);

  var d = tool.diameter;
  var r = tool.cornerRadius;
  var e = tool.diameter/2 - tool.cornerRadius;
  var f = tool.cornerRadius;
  var a = 0; // tool.tipAngle;
  var b = tool.taperAngle;
  var h = tool.shoulderLength;
  writeln("CUTTER/" + xyzFormat.format(d) + ", " + xyzFormat.format(r) + ", " + xyzFormat.format(e) + ", " + xyzFormat.format(f) + ", " + aFormat.format(a) + ", " + aFormat.format(b) + ", " + xyzFormat.format(h));

  if (tool.description) {
    writeComment(tool.description);
  }

  if (currentSection.isMultiAxis()) {
    writeln("MULTAX/ON");
  }

/*
  writeln("RAPID");
  var eulerXYZ = currentSection.workPlane.eulerXYZ;
  writeln("ROTABL/" + aFormat.format(eulerXYZ.x) + ", AAXIS");
  writeln("ROTABL/" + aFormat.format(eulerXYZ.y) + ", BAXIS");
  writeln("ROTABL/" + aFormat.format(eulerXYZ.z) + ", CAXIS");
*/

  writeln("ORIGIN/" + xyzFormat.format(currentSection.workOrigin.x) + ", " + xyzFormat.format(currentSection.workOrigin.y) + ", " + xyzFormat.format(currentSection.workOrigin.z));

  // writeln("OFSTNO/" + tool.lengthOffset); // not used

  if (isMilling()) {
    writeln("SPINDL/" + rpmFormat.format(tool.spindleRPM) + ", RPM, " + (tool.clockwise ? "CLW" : "CCLW"));
  }
  
  if (isTurning()) {
    writeln(
      "SPINDL/" + rpmFormat.format(tool.spindleRPM) + ", " + ((unit == IN) ? "SFM" : "SMM") + ", " + (tool.clockwise ? "CLW" : "CCLW")
    );
  }

  if (tool.coolant != COOLANT_OFF) {
    var mapCoolantTable = new Table(
      ["OFF", "FLOOD", "MIST", "THRU", "TAP"],
      {initial:COOLANT_OFF, force:true},
      "Invalid coolant mode"
    );
    if (mapCoolantTable.lookup(tool.coolant)) {
      writeln("COOLNT/" + mapCoolantTable.lookup(tool.coolant));
    } else {
      warning(localize("Coolant not supported."));
    }
  }
}

function onDwell(seconds) {
  writeln("DELAY/" + secFormat.format(seconds)); // in seconds
}

function onParameter(name, value) {
}

function onRadiusCompensation() {
  switch (radiusCompensation) {
  case RADIUS_COMPENSATION_OFF:
    if (radiusCompensationActive) {
      radiusCompensationActive = false;
      writeln("CUTCOM/OFF");
    }
    break;
  case RADIUS_COMPENSATION_LEFT:
    radiusCompensationActive = true;
    writeln("CUTCOM/ON, LEFT" + conditional(tool.diameterOffset != 0, ", " + tool.diameterOffset));
    break;
  case RADIUS_COMPENSATION_RIGHT:
    radiusCompensationActive = true;
    writeln("CUTCOM/ON, RIGHT" + conditional(tool.diameterOffset != 0, ", " + tool.diameterOffset));
    break;
  }
}

function onRapid(x, y, z) {
  writeln("RAPID");
  writeln("GOTO/" + xyzFormat.format(x) + ", " + xyzFormat.format(y) + ", " + xyzFormat.format(z));
}

function onLinear(x, y, z, feed) {
  if (feed != previousFeed) {
    previousFeed = feed;
    writeln("FEDRAT/" + feedFormat.format(feed) + ", " + feedUnit);
  }
  writeln("GOTO/" + xyzFormat.format(x) + ", " + xyzFormat.format(y) + ", " + xyzFormat.format(z));
}

function onRapid5D(x, y, z, dx, dy, dz) {
  writeln("RAPID");
  writeln("GOTO/" + xyzFormat.format(x) + ", " + xyzFormat.format(y) + ", " + xyzFormat.format(z) + ", " + xyzFormat.format(dx) + ", " + xyzFormat.format(dy) + ", " + xyzFormat.format(dz));
}

function onLinear5D(x, y, z, dx, dy, dz, feed) {
  if (feed != previousFeed) {
    previousFeed = feed;
    writeln("FEDRAT/" + feedFormat.format(feed) + ", " + feedUnit);
  }
  writeln("GOTO/" + xyzFormat.format(x) + ", " + xyzFormat.format(y) + ", " + xyzFormat.format(z) + ", " + xyzFormat.format(dx) + ", " + xyzFormat.format(dy) + ", " + xyzFormat.format(dz));
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (feed != previousFeed) {
    previousFeed = feed;
    writeln("FEDRAT/" + feedFormat.format(feed) + ", " + feedUnit);
  }

  var n = getCircularNormal();
  writeln(
    "MOVARC/" + xyzFormat.format(cx) + ", " + xyzFormat.format(cy) + ", " + xyzFormat.format(cz) + ", " + xyzFormat.format(n.x) + ", " + xyzFormat.format(n.y) + ", " + xyzFormat.format(n.z) + ", " + xyzFormat.format(getCircularRadius()) + ", ANGLE, " + aFormat.format(getCircularSweep())
  );
  writeln("GOTO/" + xyzFormat.format(x) + ", " + xyzFormat.format(y) + ", " + xyzFormat.format(z));
}

function onCycle() {
}

function onCyclePoint(x, y, z) {
  if (isFirstCyclePoint()) {
    var d = cycle.depth;
    var f = cycle.feedrate;
    var c = cycle.clearance - cycle.bottom;
    var r = cycle.clearance - cycle.retract;
    var q = cycle.dwell;
    var i1 = cycle.incrementalDepth; // for pecking

    var statement;

    if (cycle.clearance != undefined) {
      var p = getCurrentPosition();
      if (p.z < cycle.clearance) {
        writeln("RAPID");
        writeln("GOTO/" + xyzFormat.format(p.x) + ", " + xyzFormat.format(p.y) + ", " + xyzFormat.format(cycle.clearance));
        setCurrentPositionZ(cycle.clearance);
        writeln("RAPID");
        writeln("GOTO/" + xyzFormat.format(x) + ", " + xyzFormat.format(y) + ", " + xyzFormat.format(cycle.clearance));
        setCurrentPositionX(x);
        setCurrentPositionY(y);
      } else {
        writeln("RAPID");
        writeln("GOTO/" + xyzFormat.format(x) + ", " + xyzFormat.format(y) + ", " + xyzFormat.format(p.z));
        setCurrentPositionX(x);
        setCurrentPositionY(y);
        writeln("RAPID");
        writeln("GOTO/" + xyzFormat.format(x) + ", " + xyzFormat.format(y) + ", " + xyzFormat.format(cycle.clearance));
        setCurrentPositionZ(cycle.clearance);
      }
    }

    switch (cycleType) {
    case "drilling":
      statement = "CYCLE/DRILL, " + xyzFormat.format(d) + ", " + feedUnit + ", " + feedFormat.format(f) + ", " + xyzFormat.format(c);
      if (r > 0) {
        statement += ", RAPTO, " + xyzFormat.format(r);
      }
      if (q > 0) {
        statement += ", DWELL, " + secFormat.format(q);
      }
      break;
    case "counter-boring":
      statement = "CYCLE/DRILL, " + xyzFormat.format(d) + ", " + feedUnit + ", " + feedFormat.format(f) + ", " + xyzFormat.format(c);
      if (r > 0) {
        statement += ", RAPTO, " + xyzFormat.format(r);
      }
      if (q > 0) {
        statement += ", DWELL, " + xyzFormat.format(q);
      }
      break;
    case "reaming":
      statement = "CYCLE/REAM, " + xyzFormat.format(d) + ", " + feedUnit + ", " + feedFormat.format(f) + ", " + xyzFormat.format(c);
      if (r > 0) {
        statement += ", RAPTO, " + xyzFormat.format(r);
      }
      if (q > 0) {
        statement += ", DWELL, " + secFormat.format(q);
      }
      break;
    case "boring":
      statement = "CYCLE/BORE, " + xyzFormat.format(d) + ", " + feedUnit + ", " + feedFormat.format(f) + ", " + xyzFormat.format(c);
      if (r > 0) {
        statement += ", RAPTO, " + xyzFormat.format(r);
      }
      statement += ", ORIENT, " + aFormat.format(cycle.compensatedShiftOrientation);
      if (q > 0) {
        statement += ", DWELL, " + secFormat.format(q);
      }
      break;
    case "fine-boring":
      statement = "CYCLE/BORE, " + xyzFormat.format(d) + ", " + feedUnit + ", " + feedFormat.format(f) + ", " + xyzFormat.format(c) + ", " + xyzFormat.format(cycle.shift);
      if (r > 0) {
        statement += ", RAPTO, " + xyzFormat.format(r);
      }
      statement += ", ORIENT, " + aFormat.format(cycle.compensatedShiftOrientation);
      if (q > 0) {
        statement += ", DWELL, " + secFormat.format(q);
      }
      break;
    case "chip-breaking":
      statement = "CYCLE/BRKCHP, " + xyzFormat.format(d) + ", INCR, " + xyzFormat.format(i1) + ", " + feedUnit + ", " + feedFormat.format(f) + ", " + xyzFormat.format(c);
      if (r > 0) {
        statement += ", RAPTO, " + xyzFormat.format(r);
      }
      if (q > 0) {
        statement += ", DWELL, " + secFormat.format(q);
      }
      break;
    case "deep-drilling":
      statement = "CYCLE/DEEP, " + xyzFormat.format(d) + ", INCR, " + xyzFormat.format(i1) + ", " + feedUnit + ", " + feedFormat.format(f) + ", " + xyzFormat.format(c);
      if (r > 0) {
        statement += ", RAPTO, " + xyzFormat.format(r);
      }
      if (q > 0) {
        statement += ", DWELL, " + secFormat.format(q);
      }
      break;
    case "tapping":
      if (tool.type == TOOL_TAP_LEFT_HAND) {
        expandCyclePoint(x, y, z);
      } else {
        statement = "CYCLE/TAP, " + xyzFormat.format(d) + ", " + feedUnit + ", " + feedFormat.format(f) + ", " + xyzFormat.format(c);
        if (r > 0) {
          statement += ", RAPTO, " + xyzFormat.format(r);
        }
      }
      break;
    case "right-tapping":
      statement = "CYCLE/TAP, " + xyzFormat.format(d) + ", " + feedUnit + ", " + feedFormat.format(f) + ", " + xyzFormat.format(c);
      if (r > 0) {
        statement += ", RAPTO, " + xyzFormat.format(r);
      }
      break;
    default:
      expandCyclePoint(x, y, z);
    }
    writeln(statement);
  }

  if (!cycleExpanded) {
 // TAG: what is z relative to - stock?
    writeln("GOTO/" + xyzFormat.format(x) + ", " + xyzFormat.format(y) + ", " + xyzFormat.format(cycle.bottom + cycle.depth));
  } else {
    expandCyclePoint(x, y, z);
  }
}

function onCycleEnd() {
  if (!cycleExpanded) {
    writeln("CYCLE/OFF");
  }
  writeln("RAPID");
  var p = getCurrentPosition();
  writeln("GOTO/" + xyzFormat.format(p.x) + ", " + xyzFormat.format(p.y) + ", " + xyzFormat.format(cycle.clearance));
}

function onSectionEnd() {
  if (tool.coolant != COOLANT_OFF) {
    writeln("COOLNT/OFF");
  }

  if (currentSection.isMultiAxis()) {
    writeln("MULTAX/OFF");
  }
}

function onClose() {
  if (properties.goHome) {
    writeln("GOHOME");
  }

  writeln("END");
  writeln("FINI");
}
