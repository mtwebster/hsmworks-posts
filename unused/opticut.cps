/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Opticut post processor configuration.

  $Revision: 25831 $
  $Date: 2011-06-20 02:01:39 +0200 (ma, 20 jun 2011) $
  
  FORKID {BDD2727B-2440-4782-BA68-2B9BC978E80A}
*/

description = "Generic Opticut";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;
minimumRevision = 24000;

extension = "nc";
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
  showSequenceNumbers: true, // show sequence numbers
  sequenceNumberStart: 1, // first sequence number
  sequenceNumberIncrement: 1, // increment for sequence numbers
  separateWordsWithSpace: true // specifies that the words should be separated with a white space
};



var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});
var dFormat = createFormat({prefix:"D", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2)});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var sOutput = createVariable({prefix:"S", force:true}, rpmFormat);

// circular output
var iOutput = createVariable({prefix:"I"}, xyzFormat);
var jOutput = createVariable({prefix:"J"}, xyzFormat);
var kOutput = createVariable({prefix:"K"}, xyzFormat);

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gUnitModal = createModal({}, gFormat); // modal group 2 // G70-71
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var mPlasmaModal = createModal({}, mFormat); // M20-21

// collected state
var sequenceNumber;

/**
  Writes the specified block.
*/
function writeBlock() {
  if (properties.showSequenceNumbers) {
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
  writeln("(" + text + ")");
}

function onOpen() {
  if (!properties.separateWordsWithSpace) {
    setWordSeparator("");
  }

  sequenceNumber = properties.sequenceNumberStart;

  if (programName) {
    writeComment(programName);
  }
  if (programComment) {
    writeComment(programComment);
  }

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

  // absolute coordinates and feed per min
  writeBlock(gAbsIncModal.format(90));

  switch (unit) {
  case IN:
    writeBlock(gUnitModal.format(70));
    break;
  case MM:
    writeBlock(gUnitModal.format(71));
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

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  feedOutput.reset();
}

function getPowerMode() {
  switch (movement) {
  case MOVEMENT_CUTTING:
  //case MOVEMENT_LEAD_IN:
  //case MOVEMENT_LEAD_OUT:
  //case MOVEMENT_LINK_TRANSITION:
  //case MOVEMENT_LINK_DIRECT:
    return true;
  }
  return false;
}

function DummyModal() {
}

DummyModal.prototype.format = function(value) {
  return "";
};

function isJet() {
  switch (tool.type) {
  case TOOL_WATER_JET:
  case TOOL_LASER_CUTTER:
  case TOOL_WELDER:
    return true;
  }
  return false;
}

function onSection() {
  if ((tool.spindleRPM > 0) && !isJet()) {
    if (tool.spindleRPM > 99999) {
      warning(localize("Spindle speed exceeds maximum value."));
    }
    writeBlock(
      sOutput.format(tool.spindleRPM), mFormat.format(3)
    );
    mPlasmaModal = new DummyModal(); // disable
  } else {
    mPlasmaModal = createModal({}, mFormat); // use M20-21
  }

  forceXYZ();

  { // pure 3D
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return;
    }
    setRotation(remaining);
  }

  onCommand((tool.coolant == COOLANT_OFF) ? COMMAND_COOLANT_OFF : COMMAND_COOLANT_ON);

  forceAny();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (getCurrentPosition().z < initialPosition.z) {
    writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z), mPlasmaModal.format(20));
  }
  writeBlock(
    gAbsIncModal.format(90),
    gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y),
    mPlasmaModal.format(20)
  );
  writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z), mPlasmaModal.format(20));
}

function onDwell(seconds) {
  seconds = clamp(0.001, seconds, 99999.999);
  writeBlock(gFormat.format(4), "H" + secFormat.format(seconds));
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    }
    writeBlock(gMotionModal.format(0), x, y, z, mPlasmaModal.format(getPowerMode() ? 21 : 20));
    feedOutput.reset();
  }
}

function onLinear(_x, _y, _z, feed) {
  // at least one axis is required
  if (pendingRadiusCompensation >= 0) {
    // ensure that we end at desired position when compensation is turned off
    xOutput.reset();
    yOutput.reset();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = feedOutput.format(feed);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        writeBlock(gMotionModal.format(1), gFormat.format(41), x, y, z, f, mPlasmaModal.format(getPowerMode() ? 21 : 20));
        break;
      case RADIUS_COMPENSATION_RIGHT:
        writeBlock(gMotionModal.format(1), gFormat.format(42), x, y, z, f, mPlasmaModal.format(getPowerMode() ? 21 : 20));
        break;
      default:
        writeBlock(gMotionModal.format(1), gFormat.format(40), x, y, z, f, mPlasmaModal.format(getPowerMode() ? 21 : 20));
      }
    } else {
      writeBlock(gMotionModal.format(1), x, y, z, f, mPlasmaModal.format(getPowerMode() ? 21 : 20));
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      feedOutput.reset(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f, mPlasmaModal.format(getPowerMode() ? 21 : 20));
    }
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (pendingRadiusCompensation >= 0) {
    error("Radius compensation cannot be activated/deactivated for a circular move.");
    return;
  }

  if (isFullCircle()) {
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), zOutput.format(z), iOutput.format(cx), jOutput.format(cy), feedOutput.format(feed), mPlasmaModal.format(getPowerMode() ? 21 : 20));
      break;
    default:
      linearize(tolerance);
    }
  } else {
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx), jOutput.format(cy), feedOutput.format(feed), mPlasmaModal.format(getPowerMode() ? 21 : 20));
      break;
    default:
      linearize(tolerance);
    }
  }
}

var mapCommand = {
  COMMAND_STOP:0,
  COMMAND_END:2,
  COMMAND_SPINDLE_CLOCKWISE:3,
  COMMAND_STOP_SPINDLE:5,
  COMMAND_COOLANT_ON:8,
  COMMAND_COOLANT_OFF:9
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

  var stringId = getCommandStringId(command);
  var mcode = mapCommand[stringId];
  if (mcode != undefined) {
    writeBlock(mFormat.format(mcode));
  } else {
    onUnsupportedCommand(command);
  }
}

function onSectionEnd() {
  writeBlock(mPlasmaModal.format(getPowerMode() ? 21 : 20));
  forceAny();
}

function onClose() {
  onCommand(COMMAND_COOLANT_OFF);

  writeBlock(mFormat.format(5)); // power off
  onImpliedCommand(COMMAND_END);
  onImpliedCommand(COMMAND_STOP_SPINDLE);
  writeBlock(mFormat.format(30)); // stop program, spindle stop, coolant off
}
