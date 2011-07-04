/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  ISEL post processor configuration.

  $Revision: 25831 $
  $Date: 2011-06-20 02:01:39 +0200 (ma, 20 jun 2011) $
  
  FORKID {FF26919F-F5E0-4fcc-9408-035EEE34FAB4}
*/

description = "Generic ISEL Intermediate";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;
minimumRevision = 24000;

extension = "ncp";
setCodePage("ascii");

tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion



// user-defined properties
properties = {
  writeMachine: true, // write machine
  writeTools: true, // writes the tools
  showSequenceNumbers: true, // show sequence numbers
  sequenceNumberStart: 10, // first sequence number
  sequenceNumberIncrement: 5, // increment for sequence numbers
  forceCycleExpansion: true // expand all drilling cycles
  // optionalStop: true // optional stop
};



/** Returns the feed in mm/s. */
function toVel(feed) {
  return feed/60 * 1000;
}

/** Returns the spatial coordinate in micrometers. */
function toUM(spatial) {
  return spatial * 1000000;
}

/** Returns the angular coordinate in angular seconds. */
function toAS(angular) {
  return angular * 60 * 60;
}

var xyzFormat = createFormat({decimals:0, forceDecimal:false});
var abcFormat = createFormat({decimals:0, forceSign:false, forceDecimal:false, scale:DEG});
var feedFormat = createFormat({decimals:0, forceDecimal:false});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var milliFormat = createFormat({decimals:0}); // milliseconds // range 1-9999
var taperFormat = createFormat({decimals:1, scale:DEG});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);
var aOutput = createVariable({prefix:"A"}, abcFormat);
var bOutput = createVariable({prefix:"B"}, abcFormat);
var cOutput = createVariable({prefix:"C"}, abcFormat);
var feedOutput = createVariable({}, feedFormat);

// circular output
var iOutput = createVariable({prefix:"I", force:true}, xyzFormat);
var jOutput = createVariable({prefix:"J", force:true}, xyzFormat);



// collected state
var sequenceNumber;
var currentPlane;

/**
  Writes the specified plane.
*/
function writePlane(plane) {
  if (plane != currentPlane) {
    currentPlane = plane;
    writeBlock("PLANE " + plane);
  }
}

/**
  Writes the specified block.
*/
function writeBlock() {
  if (properties.showSequenceNumbers) {
    // up to 6 digits
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += properties.sequenceNumberIncrement;
  } else {
    writeWords(arguments);
  }
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeBlock("; " + text);
}

function onOpen() {
  machineConfiguration.setRetractPlane(0);
  machineConfiguration.setHomePositionX(0);
  machineConfiguration.setHomePositionY(0);

  if (!machineConfiguration.isMachineCoordinate(0)) {
    aOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(1)) {
    bOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(2)) {
    cOutput.disable();
  }
  
  sequenceNumber = properties.sequenceNumberStart;
  writeBlock("IMF_PBL", programName);

  if (!programName) {
    error(localize("Program name has not been specified."));
  }
  if (programComment) {
    writeComment(programComment);
  }

  writeBlock("INITTOOL"); // TAG: before each tool change?

  // dump machine configuration
  var vendor = machineConfiguration.getVendor();
  var model = machineConfiguration.getModel();
  var description = machineConfiguration.getDescription();

  if (properties.writeMachine && (vendor || model || description)) {
    writeComment(localize("Machine"));
    if (vendor) {
      writeComment("  " + localize("vendor") + ": " + vendor);
    }
    if (model) {
      writeComment("  " + localize("model") + ": " + model);
    }
    if (description) {
      writeComment("  " + localize("description") + ": "  + description);
    }
  }

  // dump tool information
  if (properties.writeTools) {
    var zRanges = {};
    if (is3D()) {
      var numberOfSections = getNumberOfSections();
      for (var i = 0; i < numberOfSections; ++i) {
        var section = getSection(i);
        var zRange = section.getGlobalZRange();
        var tool = section.getTool();
        if (zRanges[tool.number]) {
          zRanges[tool.number].expandToRange(zRange);
        } else {
          zRanges[tool.number] = zRange;
        }
      }
    }

    var tools = getToolTable();
    if (tools.getNumberOfTools() > 0) {
      for (var i = 0; i < tools.getNumberOfTools(); ++i) {
        var tool = tools.getTool(i);
        var comment = "T" + toolFormat.format(tool.number) + "  " +
          "D=" + xyzFormat.format(tool.diameter) + " " +
          localize("CR") + "=" + xyzFormat.format(tool.cornerRadius);
        if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
          comment += " " + localize("TAPER") + "=" + taperFormat.format(tool.taperAngle) + localize("deg");
        }
        if (zRanges[tool.number]) {
          comment += " - " + localize("ZMIN") + "=" + xyzFormat.format(zRanges[tool.number].getMinimum());
        }
        comment += " - " + getToolTypeName(tool.type);
        writeComment(comment);
      }
    }
  }

  switch (unit) {
  case IN:
    error(localize("Inch mode is not supported."));
    break;
  case MM:
    break;
  }
}

function onComment(message) {
  writeComment(message);
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of A, B, and C. */
function forceABC() {
  aOutput.reset();
  bOutput.reset();
  cOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and VEL on next output. */
function forceAny() {
  forceXYZ();
  forceABC();
  feedOutput.reset();
}

function onParameter(name, value) {
}

var currentWorkPlaneABC = undefined;

function setWorkPlane(abc) {
  if (!machineConfiguration.isMultiAxisConfiguration()) {
    return; // ignore
  }

  if (!((currentWorkPlaneABC == undefined) ||
        abcFormat.areDifferent(abc.x, currentWorkPlaneABC.x) ||
        abcFormat.areDifferent(abc.y, currentWorkPlaneABC.y) ||
        abcFormat.areDifferent(abc.z, currentWorkPlaneABC.z))) {
    return; // no change
  }

  onCommand(COMMAND_UNLOCK_MULTI_AXIS);

  // NOTE: add retract here

  writeBlock(
    "FASTABS",
    conditional(machineConfiguration.isMachineCoordinate(0), "A" + abcFormat.format(abc.x)),
    conditional(machineConfiguration.isMachineCoordinate(1), "B" + abcFormat.format(abc.y)),
    conditional(machineConfiguration.isMachineCoordinate(2), "C" + abcFormat.format(abc.z))
  );
  
  onCommand(COMMAND_LOCK_MULTI_AXIS);

  currentWorkPlaneABC = abc;
}

var closestABC = false; // choose closest machine angles
var currentMachineABC;

function getWorkPlaneMachineABC(workPlane) {
  var W = workPlane; // map to global frame

  var abc = machineConfiguration.getABC(W);
  if (closestABC) {
    if (currentMachineABC) {
      abc = machineConfiguration.remapToABC(abc, currentMachineABC);
    } else {
      abc = machineConfiguration.getPreferredABC(abc);
    }
  } else {
    abc = machineConfiguration.getPreferredABC(abc);
  }
  
  try {
    abc = machineConfiguration.remapABC(abc);
    currentMachineABC = abc;
  } catch (e) {
    error(
      localize("Machine angles not supported") + ":"
      + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
      + conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
      + conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
    );
  }
  
  var direction = machineConfiguration.getDirection(abc);
  if (!isSameDirection(direction, W.forward)) {
    error(localize("Orientation not supported."));
  }
  
  if (!machineConfiguration.isABCSupported(abc)) {
    error(
      localize("Work plane is not supported") + ":"
      + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
      + conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
      + conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
    );
  }

  var tcp = true;
  if (tcp) {
    setRotation(W); // TCP mode
  } else {
    var O = machineConfiguration.getOrientation(abc);
    var R = machineConfiguration.getRemainingOrientation(abc, W);
    setRotation(R);
  }
  
  return abc;
}

function onSection() {
  var insertToolCall = isFirstSection() || (tool.number != getPreviousSection().getTool().number);
  
  var retracted = false; // specifies that the tool has been retracted to the safe plane
  var newWorkPlane = isFirstSection() ||
    !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis());
  if (insertToolCall || newWorkPlane) {
    
    // retract to safe plane
    retracted = true;
    writeBlock("WPCLEAR");
    writeBlock("FASTABS", zOutput.format(toUM(machineConfiguration.getRetractPlane()))); // retract
    zOutput.reset();
    // wcs
    if (currentSection.workOffset > 0) {
      writeBlock("WPREG", currentSection.workOffset, "ACT");
    }
  }
  
  if (insertToolCall) {
    retracted = true;
    onCommand(COMMAND_COOLANT_OFF);
  
/*
    if (!isFirstSection() && properties.optionalStop) {
      onCommand(COMMAND_OPTIONAL_STOP);
    }
*/

    if (tool.number > 99) {
      warning(localize("Tool number exceeds maximum value."));
    }

    writeBlock("GETTOOL", toolFormat.format(tool.number));
    if (tool.comment) {
      writeComment(tool.comment);
    }
  }
  
  if (insertToolCall ||
      isFirstSection() ||
      (tool.spindleRPM != getPreviousSection().getTool().spindleRPM) ||
      (tool.clockwise != getPreviousSection().getTool().clockwise)) {
    if (tool.spindleRPM < 1) {
      error(localize("Spindle speed out of range."));
    }
    if (tool.spindleRPM > 99999) {
      warning(localize("Spindle speed exceeds maximum value."));
    }
    writeBlock("SPINDLE", "ON", (tool.clockwise ? "CW" : "CCW"), "RPM" + rpmFormat.format(tool.spindleRPM));
  }

  // wcs
  if (currentSection.workOffset > 0) {
    // warning(localize("Ignoring work offset."));
    if (currentSection.workOffset > 8) {
      error(localize("Work offset out of range."));
    } else {
      // output above
      // writeBlock("WPREG", currentSection.workOffset, "ACT");
    }
  }

  forceAny();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (!retracted) {
    if (getCurrentPosition().z < initialPosition.z) {
      writeBlock(
        "FASTABS", zOutput.format(toUM(initialPosition.z))
      );
    }
  }

  if (!machineConfiguration.isHeadConfiguration()) {
    writeBlock(
      "FASTABS", xOutput.format(toUM(initialPosition.x)), yOutput.format(toUM(initialPosition.y))
    );
    // handle length offset
    writeBlock("FASTABS", zOutput.format(toUM(initialPosition.z)));
  } else {
    writeBlock(
      "FASTABS",
      xOutput.format(toUM(initialPosition.x)),
      yOutput.format(toUM(initialPosition.y)),
      zOutput.format(toUM(initialPosition.z))
    );
  }
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  milliseconds = clamp(1, seconds * 1000, 99999999);
  writeBlock("WAIT", milliFormat.format(milliseconds));
}

function onCycle() {
  // go to the initial retract level
  if (!properties.forceCycleExpansion) {
    writeBlock("FASTABS", zOutput.format(toUM(cycle.clearance)));
  }
}

function onCyclePoint(x, y, z) {
  if (properties.forceCycleExpansion) {
    expandCyclePoint(x, y, z);
    return;
  }

  if (isFirstCyclePoint()) {

    var F = cycle.feedrate;
    var P = (cycle.dwell == 0) ? 0 : clamp(1, cycle.dwell * 1000, 99999999); // in milliseconds

    switch (cycleType) {
    case "drilling":
    case "counter-boring":
      writeBlock(
        "DRILLDEF", "C1",
        "P" + xyzFormat.format(toUM(cycle.stock)), // um
        "D" + xyzFormat.format(cycle.depth), // mm - positive is down
        "T" + milliFormat.format(cycle.dwell * 1000), // ms
        "V" + feedFormat.format(toVel(F)), // mm/s
        "L" + xyzFormat.format(cycle.clearance) // mm
      );
      break;
    case "chip-breaking":
      writeBlock(
        "DRILLDEF", "C2",
        "P" + xyzFormat.format(toUM(cycle.stock)), // um
        "D" + xyzFormat.format(cycle.depth), // mm - positive is down
        "T" + milliFormat.format(cycle.dwell * 1000), // ms
        "V" + feedFormat.format(toVel(F)), // mm/s
        "L" + xyzFormat.format(cycle.clearance), // mm
        "F" + xyzFormat.format(cycle.incrementalDepth), // mm
        "O" + xyzFormat.format(cycle.incrementalDepth), // mm
        "I" + xyzFormat.format(0) // mm
      );

      // cycle.accumulatedDepth is ignored
      break;
    case "deep-drilling":
     writeBlock(
        "DRILLDEF", "C2",
        "P" + xyzFormat.format(toUM(cycle.stock)), // um
        "D" + xyzFormat.format(cycle.depth), // mm - positive is down
        "T" + milliFormat.format(cycle.dwell * 1000), // ms
        "V" + feedFormat.format(toVel(F)), // mm/s
        "L" + xyzFormat.format(cycle.clearance), // mm
        "F" + xyzFormat.format(cycle.incrementalDepth), // mm
        "O" + xyzFormat.format(cycle.incrementalDepth), // mm
        "I" + xyzFormat.format(0) // mm
      );
      break;
    case "tapping":
    case "left-tapping":
    case "right-tapping":
    case "fine-boring":
    case "back-boring":
    case "reaming":
    case "stop-boring":
    case "manual-boring":
    case "boring":
    default:
      expandCyclePoint(x, y, z);
    }
  } else {
    if (cycleExpanded) {
      expandCyclePoint(x, y, z);
    } else {
      var _x = xOutput.format(toUM(x));
      var _y = yOutput.format(toUM(y));
      if (_x || _y) {
        writeBlock("DRILL", _x, _y);
      }
    }
  }
}

function onCycleEnd() {
  zOutput.reset();
}

function onRadiusCompensation() {
  if (radiusCompensation != RADIUS_COMPENSATION_OFF) { 
    error(localize("Radius compensation in the controller is not supported."));
  }
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(toUM(_x));
  var y = yOutput.format(toUM(_y));
  var z = zOutput.format(toUM(_z));
  if (x || y || z) {
    writeBlock("FASTABS", x, y, z);
    feedOutput.reset();
  }
}

function onLinear(_x, _y, _z, feed) {
  var x = xOutput.format(toUM(_x));
  var y = yOutput.format(toUM(_y));
  var z = zOutput.format(toUM(_z));
  var vel = feedOutput.format(toVel(feed));
  if (vel) {
    writeBlock("VEL", vel);
  }
  if (x || y || z) {
    writeBlock("MOVEABS", x, y, z);
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  var x = xOutput.format(toUM(_x));
  var y = yOutput.format(toUM(_y));
  var z = zOutput.format(toUM(_z));
  var a = aOutput.format(toAS(_a));
  var b = bOutput.format(toAS(_b));
  var c = cOutput.format(toAS(_c));
  var vel = feedOutput.format(toVel(feed));
  if (x || y || z || a || b || c) {
    writeBlock("MOVEABS", x, y, z, a, b, c);
    feedOutput.reset();
  }
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  var x = xOutput.format(toUM(_x));
  var y = yOutput.format(toUM(_y));
  var z = zOutput.format(toUM(_z));
  var a = aOutput.format(toAS(_a));
  var b = bOutput.format(toAS(_b));
  var c = cOutput.format(toAS(_c));
  var vel = feedOutput.format(toVel(feed));
  if (vel) {
    writeBlock("VEL", vel);
  }
  if (x || y || z || a || b || c) {

    writeBlock("MOVEABS", x, y, z, a, b, c);
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  var vel = feedOutput.format(toVel(feed));
  if (vel) {
    writeBlock("VEL", vel);
  }

  if (isFullCircle()) {
    linearize(tolerance);
  } else {
    forceXYZ();
    switch (getCircularPlane()) {
    case PLANE_XY:
      writePlane("XY");
      writeBlock(clockwise ? "CWABS" : "CCWABS", iOutput.format(toUM(cx)), jOutput.format(toUM(cy)), xOutput.format(toUM(x)), yOutput.format(toUM(y)) /*, zOutput.format(toUM(z))*/);
      break;
    case PLANE_ZX:
      writePlane("XZ");
      writeBlock(clockwise ? "CWABS" : "CCWABS", iOutput.format(toUM(cx)), jOutput.format(toUM(cz)), xOutput.format(toUM(x)) /*, yOutput.format(toUM(y))*/, zOutput.format(toUM(z)));
      break;
    case PLANE_YZ:
      writePlane("YZ");
      writeBlock(clockwise ? "CWABS" : "CCWABS", iOutput.format(toUM(cy)), jOutput.format(toUM(cz)) /*, xOutput.format(toUM(x))*/, yOutput.format(toUM(y)), zOutput.format(toUM(z)));
      break;
    default:
      linearize(tolerance);
    }
  }
}

var mapCommand = {
 COMMAND_STOP:"HALT",
 COMMAND_SPINDLE_CLOCKWISE:"SPINDLE CW",
 COMMAND_SPINDLE_COUNTERCLOCKWISE:"SPINDLE CCW",
 COMMAND_START_SPINDLE:"SPINDLE ON",
 COMMAND_STOP_SPINDLE:"SPINDLE OFF",
 COMMAND_COOLANT_ON:"COOLANT ON",
 COMMAND_COOLANT_OFF:"COOLANT OFF"
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

/*
  if (command == COMMAND_START_SPINDLE) {
    writeBlock("SPINDLE", (tool.clockwise ? "CW" : "CCW"));
    return;
  }
*/
  var stringId = getCommandStringId(command);
  var mcode = mapCommand[stringId];
  if (mcode != undefined) {
    writeBlock(mcode);
  } else {
    onUnsupportedCommand(command);
  }
}

function onSectionEnd() {
  forceAny();
}

function onClose() {
  onCommand(COMMAND_COOLANT_OFF);

  writeBlock("WPCLEAR");
  writeBlock("FASTABS", zOutput.format(toUM(machineConfiguration.getRetractPlane()))); // retract
  zOutput.reset();
  // wcs
  if (currentSection.workOffset > 0) {
    writeBlock("WPREG", currentSection.workOffset, "ACT");
  }

  setWorkPlane(new Vector(0, 0, 0)); // reset working plane

  if (!machineConfiguration.hasHomePositionX() && !machineConfiguration.hasHomePositionY()) {
    writeBlock("FASTABS", "X" + xyzFormat.format(0), "Y" + xyzFormat.format(0));
  } else {
    var homeX;
    if (machineConfiguration.hasHomePositionX()) {
      homeX = "X" + xyzFormat.format(machineConfiguration.getHomePositionX());
    }
    var homeY;
    if (machineConfiguration.hasHomePositionY()) {
      homeY = "Y" + xyzFormat.format(machineConfiguration.getHomePositionY());
    }
    writeBlock("FASTABS", homeX, homeY);
  }

  writeBlock("SPINDLE", "OFF");
  onImpliedCommand(COMMAND_STOP_SPINDLE);
  onImpliedCommand(COMMAND_END);
  writeBlock("PROGEND");
}
