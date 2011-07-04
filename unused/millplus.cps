/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  MillPlus post processor configuration.

  $Revision: 25831 $
  $Date: 2011-06-20 02:01:39 +0200 (ma, 20 jun 2011) $
  
  FORKID {72356D88-2414-401a-805E-5842DB111BB6}
*/

description = "Generic MillPlus";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;
minimumRevision = 24000;

extension = "nc";
programNameIsInteger = true;
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
  preloadTool: true, // preloads next tool on tool change if any
  showSequenceNumbers: true, // show sequence numbers
  sequenceNumberStart: 10, // first sequence number
  sequenceNumberIncrement: 1, // increment for sequence numbers
  optionalStop: true, // optional stop
  smoothingTolerance: -1, // smoothing tolerance (-1 for disabled)
  MC84: 0 // MC84 machine parameter
};



var mapCoolantTable = new Table(
  [9, 8, 7],
  {initial:COOLANT_OFF, force:true},
  "Invalid coolant mode"
);

var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});
var hFormat = createFormat({prefix:"H", decimals:0});
var dFormat = createFormat({prefix:"D", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2)});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:1}); // seconds - range 0.1-900
var taperFormat = createFormat({decimals:1, scale:DEG});

// for 5-axis motion
var tFormat = createFormat({decimals:2, forceDecimal:true, scale:100}); // unitless
var txOutput = createVariable({prefix:"I1=", force:true}, tFormat);
var tyOutput = createVariable({prefix:"J1=", force:true}, tFormat);
var tzOutput = createVariable({prefix:"K1=", force:true}, tFormat);

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);
var aOutput = createVariable({prefix:"A"}, abcFormat);
var bOutput = createVariable({prefix:"B"}, abcFormat);
var cOutput = createVariable({prefix:"C"}, abcFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var sOutput = createVariable({prefix:"S", force:true}, rpmFormat);

// circular output
var iOutput = createVariable({prefix:"I", force:true}, xyzFormat);
var jOutput = createVariable({prefix:"J", force:true}, xyzFormat);
var kOutput = createVariable({prefix:"K", force:true}, xyzFormat);

var gMotionModal = createModal({force:true}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G94-95
var gUnitModal = createModal({}, gFormat); // modal group 6 // G70-71
var gCycleModal = createModal({}, gFormat); // modal group 9 // G81, ...

var WARNING_WORK_OFFSET = 0;
var WARNING_LENGTH_OFFSET = 1;
var WARNING_DIAMETER_OFFSET = 2;

// collected state
var sequenceNumber;
var currentWorkOffset;

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
  if (properties.showSequenceNumbers) {
    writeWords2("N" + sequenceNumber, "(" + String(text) + ")");
    sequenceNumber += properties.sequenceNumberIncrement;
  } else {
    writeWords("(" + String(text) + ")");
  }
}

function onOpen() {

  if (false) { // note: setup your machine here
    var aAxis = createAxis({coordinate:0, table:false, axis:[1, 0, 0], range:[-360,360], preference:1});
    var cAxis = createAxis({coordinate:2, table:false, axis:[0, 0, 1], range:[-360,360], preference:1});
    machineConfiguration = new MachineConfiguration(aAxis, cAxis);

    setMachineConfiguration(machineConfiguration);
    optimizeMachineAngles2(0); // TCP mode
  }

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

  if (programName) {
    var programId;
    try {
      programId = getAsInt(programName);
    } catch(e) {
      error(localize("Program name must be a number."));
    }
    if (!((programId >= 1) && (programId <= 9999999))) {
      error(localize("Program number is out of range."));
    }
    writeln("%PM" + programId);
    writeln("N" + programId + " (" + programName + ")");
  } else {
    error(localize("Program name has not been specified."));
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

  // absolute coordinates and feed per min
  writeBlock(gAbsIncModal.format(90));
  writeBlock(gFeedModeModal.format(94));
  writeBlock(gPlaneModal.format(17));

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

/** Force output of A, B, and C. */
function forceABC() {
  aOutput.reset();
  bOutput.reset();
  cOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  forceABC();
  feedOutput.reset();
}

function onParameter(name, value) {
}

var currentWorkPlaneABC = undefined;
var currentWorkPlaneABCTurned = false;

function setWorkPlane(abc, turn) {
  if (is3D()) {
    return; // ignore
  }

  if (!((currentWorkPlaneABC == undefined) ||
        abcFormat.areDifferent(abc.x, currentWorkPlaneABC.x) ||
        abcFormat.areDifferent(abc.y, currentWorkPlaneABC.y) ||
        abcFormat.areDifferent(abc.z, currentWorkPlaneABC.z) ||
        (!currentWorkPlaneABCTurned && turn))) {
    return; // no change
  }
  currentWorkPlaneABC = abc;
  currentWorkPlaneABCTurned = turn;

  if (turn) {
    onCommand(COMMAND_UNLOCK_MULTI_AXIS);
  }

  if (abc.isZero()) {
    // reset working plane
    writeBlock(gFormat.format(7), "L1=" + (turn ? 1 : 0));
    forceABC();
  } else {
    writeBlock(
      gFormat.format(7),
      "A5=" + abcFormat.format(abc.x),
      "B5=" + abcFormat.format(abc.y),
      "C5=" + abcFormat.format(abc.z),
      "L1=" + (turn ? 1 : 0)
    );
  }
  
  if (turn) {
    //if (!currentSection.isMultiAxis()) {
      onCommand(COMMAND_LOCK_MULTI_AXIS);
    //}
  }
}

function onSection() {
  if (firstToolChange) { // stock - workpiece
    var workpiece = getWorkpiece();
    var delta = Vector.diff(workpiece.upper, workpiece.lower);
    if (delta.isNonZero()) {
      // G196-199 are recommended
      var offset = 10;
      writeBlock(
        gFormat.format(99), "X" + xyzFormat.format(workpiece.lower.x - offset),
        "Y" + xyzFormat.format(workpiece.lower.y - offset),
        "Z" + xyzFormat.format(workpiece.lower.z - offset),
        "I" + xyzFormat.format(delta.x + 2 * offset),
        "J" + xyzFormat.format(delta.y + 2 * offset),
        "K" + xyzFormat.format(delta.z + 2 * offset)
      );
      writeBlock(
        gFormat.format(98), "X" + xyzFormat.format(workpiece.lower.x),
        "Y" + xyzFormat.format(workpiece.lower.y),
        "Z" + xyzFormat.format(workpiece.lower.z),
        "I" + xyzFormat.format(delta.x),
        "J" + xyzFormat.format(delta.y),
        "K" + xyzFormat.format(delta.z)
      );
    }
  }

  var insertToolCall = isFirstSection() || (tool.number != getPreviousSection().getTool().number);
  
  var retracted = false; // specifies that the tool has been retracted to the safe plane
  var newWorkPlane = isFirstSection() ||
    !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis());
  if (insertToolCall || newWorkPlane) {
    
    // retract to safe plane
    if (isMultiAxis()) {
      writeBlock(gFormat.format(40));
    }
    // retract to safe plane
    retracted = true;
    writeBlock(gFormat.format(74), "Z" + xyzFormat.format(machineConfiguration.getRetractPlane()), "L1"); // retract
    zOutput.reset();
    
    if (newWorkPlane) { // reset working plane
      setWorkPlane(new Vector(0, 0, 0), false); // reset working plane
    }
  }
  
  if (insertToolCall) {
    onCommand(COMMAND_COOLANT_OFF);
  
    if (!isFirstSection() && properties.optionalStop) {
      onCommand(COMMAND_OPTIONAL_STOP);
    }

    if (tool.number > 99999999) {
      warning(localize("Tool number exceeds maximum value."));
    }

    writeBlock("T" + toolFormat.format(tool.number), mFormat.format(6));
    if (tool.comment) {
      writeComment(tool.comment);
    }
    var showToolZMin = false;
    if (showToolZMin) {
      if (is3D()) {
        var numberOfSections = getNumberOfSections();
        var zRange = currentSection.getGlobalZRange();
        var number = tool.number;
        for (var i = currentSection.getId() + 1; i < numberOfSections; ++i) {
          var section = getSection(i);
          if (section.getTool().number != number) {
            break;
          }
          zRange.expandToRange(section.getGlobalZRange());
        }
        writeComment(localize("ZMIN") + "=" + zRange.getMinimum());
      }
    }

    if (properties.preloadTool) {
      var nextTool = getNextTool(tool.number);
      if (nextTool) {
        writeBlock("T" + toolFormat.format(nextTool.number));
      } else {
        // preload first tool
        var section = getSection(0);
        var firstToolNumber = section.getTool().number;
        if (tool.number != firstToolNumber) {
          writeBlock("T" + toolFormat.format(firstToolNumber));
        }
      }
    }
  }
  
  if (insertToolCall ||
      isFirstSection() ||
      (tool.spindleRPM != getPreviousSection().getTool().spindleRPM) ||
      (tool.clockwise != getPreviousSection().getTool().clockwise)) {
    if (tool.spindleRPM < 1) {
      error(localize("Spindle speed out of range."));
    }
    if (tool.spindleRPM > 99999) { // machine specific
      warning(localize("Spindle speed exceeds maximum value."));
    }
    writeBlock(
      sOutput.format(tool.spindleRPM), mFormat.format(tool.clockwise ? 3 : 4)
    );
  }

  // wcs
  var workOffset = currentSection.workOffset;
  if (workOffset == 0) {
    if (properties.MC84 == 0) {
      warningOnce(localize("Work offset has not been specified. Using G54 as WCS."), WARNING_WORK_OFFSET);
    } else {
      warningOnce(localize("Work offset has not been specified. Using G54 I0 as WCS."), WARNING_WORK_OFFSET);
    }
    workOffset = 1;
  }
  if (workOffset > 0) {
    if (properties.MC84 == 0) {
      if (workOffset > 6) {
        error(localize("Work offset out of range."));
      }
      if (workOffset != currentWorkOffset) {
        writeBlock(gFormat.format(53 + workOffset)); // G54->G59
        currentWorkOffset = workOffset;
      }
    } else {
      if (workOffset > 99) {
        error(localize("Work offset out of range."));
      }
      if (workOffset != currentWorkOffset) {
        writeBlock(gFormat.format(54), "I" + (workOffset - 1));
        currentWorkOffset = workOffset;
      }
    }
  }

  forceXYZ();

  if (!is3D() || machineConfiguration.isMultiAxisConfiguration()) { // use 5-axis indexing for multi-axis mode
    // set working plane after datum shift

    var abc = new Vector(0, 0, 0);
    cancelTransformation();
    if (!currentSection.isMultiAxis()) {
      abc = currentSection.workPlane.eulerXYZ;
    }
    setWorkPlane(abc, true); // turn
  } else { // pure 3D
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return;
    }
    setRotation(remaining);
  }

  // set coolant after we have positioned at Z
  {
    var c = mapCoolantTable.lookup(tool.coolant);
    if (c) {
      writeBlock(mFormat.format(c));
    } else {
      warning(localize("Coolant not supported."));
    }
  }

  forceAny();

  if (isMultiAxis()) {
    writeBlock(
      gFormat.format(141), "R" + xyzFormat.format(tool.diameter/2),
      "R1=" + xyzFormat.format(tool.cornerRadius),
      "L2=0"
    );
  }

  if (tool.lengthOffset != 0) {
    warningOnce(localize("Length offset is not supported."), WARNING_LENGTH_OFFSET);
  }
  
  if (isMultiAxis()) {
    writeBlock(gFormat.format(141)); // TCPM - absolute positions
  }

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (!retracted) {
    if (getCurrentPosition().z < initialPosition.z) {
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
    }
  }
  
  if (!machineConfiguration.isHeadConfiguration()) {
    writeBlock(gAbsIncModal.format(90));
    writeBlock(
      gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y)
    );
    var z = zOutput.format(initialPosition.z);
    if (z) {
      writeBlock(gMotionModal.format(0), z);
    }
  } else {
    writeBlock(gAbsIncModal.format(90));
    writeBlock(
      gMotionModal.format(0),
      xOutput.format(initialPosition.x),
      yOutput.format(initialPosition.y),
      zOutput.format(initialPosition.z)
    );
  }

  if (insertToolCall) {
    gPlaneModal.reset();
  }
}

var expandCycle;

function onDrilling(cycle) {
  onCounterBoring(cycle);
}

function onCounterBoring(cycle) {
  writeBlock(gAbsIncModal.format(90));
  writeBlock(
    gCycleModal.format(81),
    "Z" + xyzFormat.format(-cycle.depth),
    "Y" + xyzFormat.format(cycle.retract - cycle.stock),
    conditional(cycle.clearance > cycle.retract, "B" + xyzFormat.format(cycle.clearance - cycle.retract)),
    conditional(cycle.dwell > 0, "X" + secFormat.format(clamp(0.1, cycle.dwell, 900))),
    feedOutput.format(cycle.feedrate)
  );
}

function onChipBreaking(cycle) {
  writeBlock(gAbsIncModal.format(90));
  writeBlock(
    gCycleModal.format(83),
    "Z" + xyzFormat.format(-cycle.depth),
    "Y" + xyzFormat.format(cycle.retract - cycle.stock),
    conditional(cycle.clearance > cycle.retract, "B" + xyzFormat.format(cycle.clearance - cycle.retract)),
    "K" + xyzFormat.format(cycle.incrementalDepth),
    "I0",
    "J" + xyzFormat.format((cycle.chipBreakDistance != undefined) ? cycle.chipBreakDistance : machineParameters.chipBreakingDistance),
    "K1=" + cycle.plungesPerRetract,
    conditional(cycle.dwell > 0, "X" + secFormat.format(clamp(0.1, cycle.dwell, 900))),
    feedOutput.format(cycle.feedrate)
  );
}

function onDeepDrilling(cycle) {
  writeBlock(gAbsIncModal.format(90));
  writeBlock(
    gCycleModal.format(83),
    "Z" + xyzFormat.format(-cycle.depth),
    "Y" + xyzFormat.format(cycle.retract - cycle.stock),
    conditional(cycle.clearance > cycle.retract, "B" + xyzFormat.format(cycle.clearance - cycle.retract)),
    "K" + xyzFormat.format(cycle.incrementalDepth),
    "I0",
    "J0",
    conditional(cycle.dwell > 0, "X" + secFormat.format(clamp(0.1, cycle.dwell, 900))),
    feedOutput.format(cycle.feedrate)
  );
}

function onLeftTapping(cycle) {
  error(localize("Left tapping is not supported."));
}

function onRightTapping(cycle) {
  writeBlock(gAbsIncModal.format(90));
  writeBlock(
    gCycleModal.format(84),
    "Z" + xyzFormat.format(-cycle.depth),
    "Y" + xyzFormat.format(cycle.retract - cycle.stock),
    conditional(cycle.clearance > cycle.retract, "B" + xyzFormat.format(cycle.clearance - cycle.retract)),
    conditional(cycle.dwell > 0, "X" + secFormat.format(clamp(0.1, cycle.dwell, 900))),
    // feedOutput.format(cycle.feedrate),
    "J" + xyzFormat.format(tool.threadPitch),
    "I1=1"
  );
}

function onReaming(cycle) {
  onBoring(cycle);
}

function onStopBoring(cycle) {
  writeBlock(gAbsIncModal.format(90));
  writeBlock(
    gCycleModal.format(86),
    "Z" + xyzFormat.format(-cycle.depth),
    "Y" + xyzFormat.format(cycle.retract - cycle.stock),
    conditional(cycle.clearance > cycle.retract, "B" + xyzFormat.format(cycle.clearance - cycle.retract)),
    conditional(cycle.dwell > 0, "X" + secFormat.format(clamp(0.1, cycle.dwell, 900))),
    feedOutput.format(cycle.feedrate)
  );
}

function onBoring(cycle) {
  writeBlock(gAbsIncModal.format(90));
  writeBlock(
    gCycleModal.format(85),
    "Z" + xyzFormat.format(-cycle.depth),
    "Y" + xyzFormat.format(cycle.retract - cycle.stock),
    conditional(cycle.clearance > cycle.retract, "B" + xyzFormat.format(cycle.clearance - cycle.retract)),
    conditional(cycle.dwell > 0, "X" + secFormat.format(clamp(0.1, cycle.dwell, 900))),
    feedOutput.format(cycle.feedrate),
    conditional(cycle.retractFeedrate != cycle.feedrate, "F2=" + feedFormat.format(cycle.retractFeedrate))
  );
}

function onDwell(seconds) {
  if (seconds > 900) {
    warning(localize("Dwelling time is out of range."));
  }
  seconds = clamp(0.1, seconds, 900);
  writeBlock(gFormat.format(4), "X" + secFormat.format(seconds));
}

function onCycle() {
  writeBlock(gPlaneModal.format(17));

  // go to the initial retract level
  if (getCurrentPosition().z > cycle.clearance) {
    if (getNumberOfCyclePoints() > 0) {
      var p = getCyclePoint(0);
      writeBlock(gMotionModal.format(0), xOutput.format(p.x), yOutput.format(p.y));
    }
  }
  writeBlock(gMotionModal.format(0), zOutput.format(cycle.clearance));
  setCurrentPositionZ(cycle.clearance);

  expandCycle = false;
  
  switch (cycleType) {
  case "drilling": // G81 style
    onDrilling(cycle);
    break;
  case "counter-boring":
    onCounterBoring(cycle);
    break;
  case "chip-breaking":
    onChipBreaking(cycle);
    break;
  case "deep-drilling":
    onDeepDrilling(cycle);
    break;
  case "tapping":
    if (tool.type == TOOL_TAP_LEFT_HAND) {
      expandCycle = true;
    } else {
      onRightTapping(cycle);
    }
    break;
  case "left-tapping":
    expandCycle = true;
    break;
  case "right-tapping":
    onRightTapping(cycle);
    break;
  case "back-boring":
    var revolutions = 0;
    if (cycle.dwell > 0) {
      revolutions = sOutput.getCurrent() * cycle.dwell/60;
    }
    writeBlock(gAbsIncModal.format(90));
    writeBlock(
      gCycleModal.format(790),
      "L" + xyzFormat.format(cycle.backBoreDistance),
      "Z" + xyzFormat.format(-cycle.depth),
      "L1=" + xyzFormat.format(cycle.retract - cycle.stock),
      conditional(cycle.clearance > cycle.retract, "L2=" + xyzFormat.format(cycle.clearance - cycle.retract)),
      "C1=" + xyzFormat.format(cycle.shift),
      "C2=0",
      "D" + angleFormat.format(cycle.shiftAngle),
      conditional(revolutions > 0, "D3=" + revFormat.format(revolutions)),
      feedOutput.format(cycle.feedrate)
    );
    break;
  case "reaming":
    onReaming(cycle);
    break;
  case "stop-boring":
    onStopBoring(cycle);
    break;
  case "fine-boring":
    onFineBoring(cycle);
    break;
  case "boring":
    onBoring(cycle);
    break;
  default:
    expandCycle = true;
  }
}

function onCyclePoint(x, y, z) {
  if (!expandCycle) {
    xOutput.reset();
    yOutput.reset();
    zOutput.reset();
    writeBlock(
      gFormat.format(79),
      xOutput.format(x),
      yOutput.format(y),
      zOutput.format(cycle.stock)
    );
  } else {
    expandCyclePoint(x, y, z);
  }
}

function onCycleEnd() {
  expandCycle = false;
  zOutput.reset();
  gCycleModal.reset();

  switch (cycleType) {
  case "tapping":
    if (tool.type == TOOL_TAP_LEFT_HAND) {
      // not supported
    } else {
      onCommand(COMMAND_SPINDLE_CLOCKWISE);
    }
    break;
  case "left-tapping":
    // not supported
    break;
  case "right-tapping":
    onCommand(COMMAND_SPINDLE_CLOCKWISE);
    break;
  }
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
    writeBlock(gMotionModal.format(0), x, y, z);
    feedOutput.reset();
  }
}

function onLinear(_x, _y, _z, feed) {
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
      if (tool.diameterOffset) {
        warningOnce(localize("Diameter offset is not supported."), WARNING_DIAMETER_OFFSET);
      }
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        writeBlock(gPlaneModal.format(17));
        writeBlock(gFormat.format(43));
        writeBlock(gFormat.format(41));
        writeBlock(gMotionModal.format(1), x, y, z, f);
        break;
      case RADIUS_COMPENSATION_RIGHT:
        writeBlock(gPlaneModal.format(17));
        writeBlock(gFormat.format(43));
        writeBlock(gFormat.format(42));
        writeBlock(gMotionModal.format(1), x, y, z, f);
        break;
      default:
        writeBlock(gFormat.format(40));
        writeBlock(gMotionModal.format(1), x, y, z, f);
      }
    } else {
      writeBlock(gMotionModal.format(1), x, y, z, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      feedOutput.reset(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation mode cannot be changed at rapid traversal."));
  }

  if (machineConfiguration.isMultiAxisConfiguration()) {
    var x = xOutput.format(_x);
    var y = yOutput.format(_y);
    var z = zOutput.format(_z);
    var a = aOutput.format(_a);
    var b = bOutput.format(_b);
    var c = cOutput.format(_c);
    writeBlock(gMotionModal.format(0), x, y, z, a, b, c);
  } else {
    forceXYZ(); // required
    var x = xOutput.format(_x);
    var y = yOutput.format(_y);
    var z = zOutput.format(_z);
    var i = txOutput.format(_a);
    var j = tyOutput.format(_b);
    var k = tzOutput.format(_c);
    writeBlock(gMotionModal.format(0), x, y, z, i, j, k);
  }
  feedOutput.reset();
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  if (pendingRadiusCompensation >= 0) {
    error("Radius compensation cannot be activated/deactivated for 5-axis move.");
  }

  if (machineConfiguration.isMultiAxisConfiguration()) {
    var x = xOutput.format(_x);
    var y = yOutput.format(_y);
    var z = zOutput.format(_z);
    var a = aOutput.format(_a);
    var b = bOutput.format(_b);
    var c = cOutput.format(_c);
    var f = feedOutput.format(feed);
    writeBlock(gMotionModal.format(1), x, y, z, a, b, c, f);
  } else {
    forceXYZ(); // required
    var x = xOutput.format(_x);
    var y = yOutput.format(_y);
    var z = zOutput.format(_z);
    var i = txOutput.format(_a);
    var j = tyOutput.format(_b);
    var k = tzOutput.format(_c);
    var f = feedOutput.format(feed);
    writeBlock(gMotionModal.format(1), x, y, z, i, j, k, f);
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (pendingRadiusCompensation >= 0) {
    error("Radius compensation cannot be activated/deactivated for a circular move.");
  }

  writeBlock(gAbsIncModal.format(90));
  var start = getCurrentPosition();

  if (isFullCircle()) {
    if (isHelical()) {
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), iOutput.format(cx), jOutput.format(cy), "B5=360", feedOutput.format(feed));
      break;
    case PLANE_ZX:
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), iOutput.format(cx), kOutput.format(cz), "B5=360", feedOutput.format(feed));
      break;
    case PLANE_YZ:
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), jOutput.format(cy), kOutput.format(cz), "B5=360", feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else {
    switch (getCircularPlane()) {
    case PLANE_XY:
      xOutput.reset();
      yOutput.reset();
      writeBlock(
        gMotionModal.format(clockwise ? 2 : 3),
        xOutput.format(x),
        yOutput.format(y),
        conditional(isHelical(), zOutput.format(z)),
        iOutput.format(cx),
        jOutput.format(cy),
        conditional(isHelical(), "K" + xyzFormat.format(getHelicalPitch())),
        feedOutput.format(feed)
      );
      break;
    case PLANE_ZX:
      if (isHelical()) {
        linearize(tolerance);
        return;
      }

      xOutput.reset();
      zOutput.reset();
      writeBlock(
        gMotionModal.format(clockwise ? 2 : 3),
        xOutput.format(x),
        conditional(isHelical(), yOutput.format(y)),
        zOutput.format(z),
        iOutput.format(cx),
        conditional(isHelical(), "J" + xyzFormat.format(getHelicalPitch())),
        kOutput.format(cz),
        feedOutput.format(feed)
      );
      break;
    case PLANE_YZ:
      if (isHelical()) {
        linearize(tolerance);
        return;
      }

      yOutput.reset();
      zOutput.reset();
      writeBlock(
        gMotionModal.format(clockwise ? 2 : 3),
        conditional(isHelical(), xOutput.format(x)),
        yOutput.format(y),
        zOutput.format(z),
        conditional(isHelical(), "I" + xyzFormat.format(getHelicalPitch())),
        jOutput.format(cy),
        kOutput.format(cz),
        feedOutput.format(feed)
      );
      break;
    default:
      linearize(tolerance);
    }
  }
}

var mapCommand = {
  COMMAND_STOP:0,
  COMMAND_OPTIONAL_STOP:1,
  COMMAND_END:30,
  COMMAND_SPINDLE_CLOCKWISE:3,
  COMMAND_SPINDLE_COUNTERCLOCKWISE:4,
  COMMAND_STOP_SPINDLE:5,
  COMMAND_ORIENTATE_SPINDLE:19,
  COMMAND_LOAD_TOOL:6,
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
  if (isMultiAxis()) {
    writeBlock(gFormat.format(40));
  }

  writeBlock(gPlaneModal.format(17));
  forceAny();
}

function onClose() {
  onCommand(COMMAND_COOLANT_OFF);

  writeBlock(gFormat.format(74), "Z" + xyzFormat.format(machineConfiguration.getRetractPlane()), "L1"); // retract
  zOutput.reset();

  setWorkPlane(new Vector(0, 0, 0), true); // reset working plane

  var homeX;
  if (machineConfiguration.hasHomePositionX()) {
    homeX = "X" + xyzFormat.format(machineConfiguration.getHomePositionX());
  }
  var homeY;
  if (machineConfiguration.hasHomePositionY()) {
    homeY = "Y" + xyzFormat.format(machineConfiguration.getHomePositionY());
  }
  if (homeX || homeY) {
    writeBlock(gFormat.format(74), homeX, homeY, "L1"); // return to home
  }

  onImpliedCommand(COMMAND_END);
  onImpliedCommand(COMMAND_STOP_SPINDLE);
  writeBlock(mFormat.format(30)); // stop program, spindle stop, coolant off
}
