/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Siemens SINUMERIK 840D post processor configuration.

  $Revision: 25843 $
  $Date: 2011-06-20 23:42:50 +0200 (ma, 20 jun 2011) $
  
  FORKID {75AF44EA-0A42-4803-8DE7-43BF08B352B3}
*/

description = "Siemens SINUMERIK 840D";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;
minimumRevision = 24000;

extension = "mpf";
setCodePage("ascii");

tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
var useArcTurn = true;
maximumCircularSweep = toRad(999 * 360); // max revolutions
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
  useShortestDirection: true // specifies that shortest angular direction should be used
};



var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});
var hFormat = createFormat({prefix:"H", decimals:0});
var dFormat = createFormat({prefix:"D", decimals:0});
var nFormat = createFormat({prefix:"N", decimals:0});


var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var abcFormat = createFormat({decimals:3, scale:DEG});
var abcDirectFormat = createFormat({decimals:3, forceSign:true, scale:DEG, prefix="=DC(", suffix=")"});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2)});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3});
var taperFormat = createFormat({decimals:1, scale:DEG});
var arFormat = createFormat({decimals:3, scale:DEG});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);
var a3Output = createVariable({prefix:"A3=", force:true}, xyzFormat);
var b3Output = createVariable({prefix:"B3=", force:true}, xyzFormat);
var c3Output = createVariable({prefix:"C3=", force:true}, xyzFormat);
var aOutput = createVariable({prefix:"A"}, abcFormat);
var bOutput = createVariable({prefix:"B"}, abcFormat);
var cOutput = createVariable({prefix:"C"}, abcFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var sOutput = createVariable({prefix:"S"}, rpmFormat);
var dOutput = createVariable({}, dFormat);

// circular output
var iOutput = createReferenceVariable({prefix:"I", force:true}, xyzFormat);
var jOutput = createReferenceVariable({prefix:"J", force:true}, xyzFormat);
var kOutput = createReferenceVariable({prefix:"K", force:true}, xyzFormat);

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G94-95
var gUnitModal = createModal({}, gFormat); // modal group 6 // G70-71

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
    writeWords2("N" + sequenceNumber, "; " + text);
    sequenceNumber += properties.sequenceNumberIncrement;
  } else {
    writeWords("; " + text);
  }
}

function onOpen() {
  if (!machineConfiguration.isMachineCoordinate(0)) {
    aOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(1)) {
    bOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(2)) {
    cOutput.disable();
  }
  
  if (properties.useShortestDirection) {
    abcFormat = abcDirectFormat;
  }

  sequenceNumber = properties.sequenceNumberStart;
  // if (!((programName.length >= 2) && (isAlpha(programName[0]) || (programName[0] == "_")) && isAlpha(programName[1]))) {
  //   error(localize("Program name must begin with 2 letters."));
  // }
  writeln("; %_N_" + translateText(String(programName).toUpperCase(), " ", "_") + "_MPF");
  
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
  writeBlock(gAbsIncModal.format(90), gFeedModeModal.format(94));

  switch (unit) {
  case IN:
    writeBlock(gUnitModal.format(70)); // lengths
    //writeBlock(gFormat.format(700)); // feeds
    break;
  case MM:
    writeBlock(gUnitModal.format(71)); // lengths
    //writeBlock(gFormat.format(710)); // feeds
    break;
  }

  writeBlock(gFormat.format(64)); // continuous-path mode
  writeBlock(gPlaneModal.format(17));
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

  var FR = 0;
  var TC = "";
  var ST = 0;
  var MODE = 57;
  var X0 = 0;
  var Y0 = 0;
  var Z0 = 0;
  var A = abc.x;
  var B = abc.y;
  var C = abc.z;
  var X1 = 0;
  var Y1 = 0;
  var Z1 = 0;
  var DIR = turn ? -1 : 0; // direction
      
  writeBlock(
    "CYCLE800(" + 
    FR + ", " +
    "\"" + TC + "\", " +
    ST + ", " +
    MODE + ", " +
    xyzFormat.format(X0) + ", " +
    xyzFormat.format(Y0) + ", " +
    xyzFormat.format(Z0) + ", " +
    abcFormat.format(A) + ", " +
    abcFormat.format(B) + ", " +
    abcFormat.format(C) + ", " +
    xyzFormat.format(X1) + ", " +
    xyzFormat.format(Y1) + ", " +
    xyzFormat.format(Z1) + ", " +
    DIR + ")"
  );
  forceABC();
  forceXYZ();

  if (turn) {
    //if (!currentSection.isMultiAxis()) {
      onCommand(COMMAND_LOCK_MULTI_AXIS);
    //}
  }
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
    writeBlock(gMotionModal.format(0), "SUPA", "Z" + machineConfiguration.getRetractPlane(), "D0"); // retract
    zOutput.reset();
    
    if (newWorkPlane) {
      setWorkPlane(new Vector(0, 0, 0), false); // reset working plane
    }
  }
  
  if (insertToolCall) {
    retracted = true;
    onCommand(COMMAND_COOLANT_OFF);
  
    if (!isFirstSection() && properties.optionalStop) {
      onCommand(COMMAND_OPTIONAL_STOP);
    }

    if (tool.number > 99999999) {
      warning(localize("Tool number exceeds maximum value."));
    }

    writeBlock("T" + toolFormat.format(tool.number));
    writeBlock(mFormat.format(6));
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
    if (tool.spindleRPM > 99999) {
      warning(localize("Spindle speed exceeds maximum value."));
    }
    writeBlock(
      sOutput.format(tool.spindleRPM), mFormat.format(tool.clockwise ? 3 : 4)
    );
  }

  // wcs
  var workOffset = currentSection.workOffset;
  if (workOffset == 0) {
    warningOnce(localize("Work offset has not been specified. Using G54 as WCS."), WARNING_WORK_OFFSET);
    workOffset = 1;
  }
  if (workOffset > 0) {
    if (workOffset > 4) {
      var code = 500 + workOffset - 4 + 4;
      if (code > 599) {
        error(localize("Work offset out of range."));
      }
      if (workOffset != currentWorkOffset) {
        writeBlock(gFormat.format(code));
        currentWorkOffset = workOffset;
      }
    } else {
      if (workOffset != currentWorkOffset) {
        writeBlock(gFormat.format(53 + workOffset)); // G54->G59
        currentWorkOffset = workOffset;
      }
    }
  }

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

  forceAny();

  if (!currentSection.isMultiAxis()) {
    onCommand(COMMAND_LOCK_MULTI_AXIS);
  }

  if (currentSection.isMultiAxis()) {
    cancelTransformation();

    writeBlock("TRAORI");

    // turn machine
    if (machineConfiguration.isMultiAxisConfiguration()) {
      var abc = currentSection.getInitialToolAxisABC();
      writeBlock(gAbsIncModal.format(90), gMotionModal.format(0), aOutput.format(abc.x), bOutput.format(abc.y), cOutput.format(abc.z));
    } else {
      var d = currentSection.getGlobalInitialToolAxis();
      var a3 = a3Output.format(d.x);
      var b3 = b3Output.format(d.y);
      var c3 = c3Output.format(d.z);
      writeBlock(gAbsIncModal.format(90), gMotionModal.format(0), a3, b3, c3);
    }

    var initialPosition = getFramePosition(currentSection.getInitialPosition());

    writeBlock("D1");
    writeBlock(
      gAbsIncModal.format(90),
      gMotionModal.format(0),
      xOutput.format(initialPosition.x),
      yOutput.format(initialPosition.y),
      zOutput.format(initialPosition.z)
    );
  } else {

    var initialPosition = getFramePosition(currentSection.getInitialPosition());
    if (!retracted) {
      if (getCurrentPosition().z < initialPosition.z) {
        writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
      }
    }

    if (insertToolCall) {
      if (tool.lengthOffset != 0) {
        warningOnce(localize("Length offset is not supported."), WARNING_LENGTH_OFFSET);
      }

      if (!machineConfiguration.isHeadConfiguration()) {
        writeBlock(
          gAbsIncModal.format(90),
          gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y)
        );
        writeBlock("D1");
        var z = zOutput.format(initialPosition.z);
        if (z) {
          writeBlock(gMotionModal.format(0), z);
        }
      } else {
        writeBlock("D1");
        writeBlock(
          gAbsIncModal.format(90),
          gMotionModal.format(0),
          xOutput.format(initialPosition.x),
          yOutput.format(initialPosition.y),
          zOutput.format(initialPosition.z)
        );
      }
    } else {
      writeBlock(
        gAbsIncModal.format(90),
        gMotionModal.format(0),
        xOutput.format(initialPosition.x),
        yOutput.format(initialPosition.y)
      );
    }
  }

  // set coolant after we have positioned at Z
  if (insertToolCall) {
    forceCoolant();
  }
  setCoolant(tool.coolant);

  if (insertToolCall) {
    gPlaneModal.reset();
  }
}

function onDwell(seconds) {
  if (seconds > 0) {
    writeBlock(gFormat.format(4), "F" + secFormat.format(seconds));
  }
}

var expandCurrentCycle = false;

function onCycle() {
  writeBlock(gPlaneModal.format(17));
  
  expandCurrentCycle = false;

  writeBlock(feedOutput.format(cycle.feedrate));

  var RTP = cycle.clearance; // return plane (absolute)
  var RFP = cycle.stock; // reference plane (absolute)
  var SDIS = cycle.retract - cycle.stock; // safety distance
  var DP = cycle.bottom; // depth (absolute)
  // var DPR = RFP - cycle.bottom; // depth (relative to reference plane)
  var DTB = cycle.dwell;
  var SDIR = tool.clockwise ? 3 : 4; // direction of rotation: M3:3 and M4:4

  switch (cycleType) {
  case "drilling":
    writeBlock(
      "MCALL CYCLE81(" + xyzFormat.format(RTP) +
      ", " + xyzFormat.format(RFP) +
      ", " + xyzFormat.format(SDIS) +
      ", " + xyzFormat.format(DP) +
      ", " /*+ xyzFormat.format(DPR)*/ + ")"
    );
    break;
  case "counter-boring":
    writeBlock(
      "MCALL CYCLE82(" + xyzFormat.format(RTP) +
      ", " + xyzFormat.format(RFP) +
      ", " + xyzFormat.format(SDIS) +
      ", " + xyzFormat.format(DP) +
      ", " /*+ xyzFormat.format(DPR)*/ +
      ", " + conditional(DTB > 0, secFormat.format(DTB)) + ")"
    );
    break;
  case "chip-breaking":
    // add support for accumulated depth
    var FDEP = cycle.stock - cycle.incrementalDepth;
    var FDPR = cycle.incrementalDepth; // relative to reference plane (unsigned)
    var DAM = 0; // degression (unsigned)
    var DTS = 0; // dwell time at start
    var FRF = 1; // feedrate factor (unsigned)
    var VARI = 0; // chip breaking
    var _AXN = 3; // tool axis
    var _MDEP = cycle.incrementalDepth; // minimum drilling depth
    var _VRT = 0; // retraction distance
    var _DTD = (cycle.dwell != undefined) ? cycle.dwell : 0;
    var _DIS1 = 0; // limit distance

    writeBlock(
      "MCALL CYCLE83(" + xyzFormat.format(RTP) +
      ", " + xyzFormat.format(RFP) +
      ", " + xyzFormat.format(SDIS) +
      ", " + xyzFormat.format(DP) +
      ", " /*+ xyzFormat.format(DPR)*/ +
      ", " + xyzFormat.format(FDEP) +
      ", " /*+ xyzFormat.format(FDPR)*/ +
      ", " + xyzFormat.format(DAM) +
      ", " + /*conditional(DTB > 0, secFormat.format(DTB))*/ // only dwell at bottom
      ", " + conditional(DTS > 0, secFormat.format(DTS)) +
      ", " + xyzFormat.format(FRF) +
      ", " + xyzFormat.format(VARI) +
      ", " + /*_AXN +*/
      ", " + xyzFormat.format(_MDEP) +
      ", " + xyzFormat.format(_VRT) +
      ", " + secFormat.format(_DTD) +
      ", 0" + /*xyzFormat.format(_DIS1) +*/
      ")"
    );
    break;
  case "deep-drilling":
    var FDEP = cycle.stock - cycle.incrementalDepth;
    var FDPR = cycle.incrementalDepth; // relative to reference plane (unsigned)
    var DAM = 0; // degression (unsigned)
    var DTS = 0; // dwell time at start
    var FRF = 1; // feedrate factor (unsigned)
    var VARI = 0; // chip breaking (so we only dwell at final depth)
    var _MDEP = cycle.incrementalDepth; // minimum drilling depth
    var _VRT = 0; // retraction distance
    var _DTD = (cycle.dwell != undefined) ? cycle.dwell : 0;
    var _DIS1 = 0; // limit distance

    writeBlock(
      "MCALL CYCLE83(" + xyzFormat.format(RTP) +
      ", " + xyzFormat.format(RFP) +
      ", " + xyzFormat.format(SDIS) +
      ", " + xyzFormat.format(DP) +
      ", " /*+ xyzFormat.format(DPR)*/ +
      ", " + xyzFormat.format(FDEP) +
      ", " /*+ xyzFormat.format(FDPR)*/ +
      ", " + xyzFormat.format(DAM) +
      ", " + /*conditional(DTB > 0, secFormat.format(DTB)) +*/ // only dwell at bottom
      ", " + conditional(DTS > 0, secFormat.format(DTS)) +
      ", " + xyzFormat.format(FRF) +
      ", " + xyzFormat.format(VARI) +
      ", " + /*_AXN +*/
      ", " + xyzFormat.format(_MDEP) +
      ", " + xyzFormat.format(_VRT) +
      ", " + secFormat.format(_DTD) +
      ", 0" + /*xyzFormat.format(_DIS1) +*/
      ")"
    );
    break;
  case "tapping":
  case "left-tapping":
  case "right-tapping":
    var SDAC = SDIR; // direction of rotation after end of cycle
    var MPIT = 0; // thread pitch as thread size
    var PIT = ((tool.type == TOOL_TAP_LEFT_HAND) ? -1 : 1) * tool.threadPitch; // thread pitch
    var POSS = 0; // spindle position for oriented spindle stop in cycle (in degrees)
    var SST = 0; // speed for tapping
    var SST1 = 0; // speed for return
    writeBlock(
      "MCALL CYCLE84(" + xyzFormat.format(RTP) +
      ", " + xyzFormat.format(RFP) +
      ", " + xyzFormat.format(SDIS) +
      ", " + xyzFormat.format(DP) +
      ", " /*+ xyzFormat.format(DPR)*/ +
      ", " + conditional(DTB > 0, secFormat.format(DTB)) +
      ", " + xyzFormat.format(SDAC) +
      ", " + xyzFormat.format(MPIT) +
      ", " + xyzFormat.format(PIT) +
      ", " + xyzFormat.format(POSS) +
      ", " + xyzFormat.format(SST) +
      ", " + xyzFormat.format(SST1) + ")"
    );
    break;
  case "reaming":
    var FFR = cycle.feedrate;
    var RFF = cycle.retractFeedrate;
    writeBlock(
      "MCALL CYCLE85(" + xyzFormat.format(RTP) +
      ", " + xyzFormat.format(RFP) +
      ", " + xyzFormat.format(SDIS) +
      ", " + xyzFormat.format(DP) +
      ", " /*+ xyzFormat.format(DPR)*/ +
      ", " + conditional(DTB > 0, secFormat.format(DTB)) +
      ", " + xyzFormat.format(FFR) +
      ", " + xyzFormat.format(RFF) + ")"
    );
    break;
  case "stop-boring":
    if (cycle.dwell > 0) {
      expandCurrentCycle = true;
    } else {
      writeBlock(
        "MCALL CYCLE87(" + xyzFormat.format(RTP) +
        ", " + xyzFormat.format(RFP) +
        ", " + xyzFormat.format(SDIS) +
        ", " + xyzFormat.format(DP) +
        ", " /*+ xyzFormat.format(DPR)*/ +
        ", " + SDIR + ")"
      );
    }
    break;
  case "fine-boring":
    var RPA = 0; // return path in abscissa of the active plane (enter incrementally with)
    var RPO = 0; // return path in the ordinate of the active plane (enter incrementally sign)
    var RPAP = 0; // return plane in the applicate (enter incrementally with sign)
    var POSS = 0; // spindle position for oriented spindle stop in cycle (in degrees)
    writeBlock(
      "MCALL CYCLE86(" + xyzFormat.format(RTP) +
      ", " + xyzFormat.format(RFP) +
      ", " + xyzFormat.format(SDIS) +
      ", " + xyzFormat.format(DP) +
      ", " /*+ xyzFormat.format(DPR)*/ +
      ", " + conditional(DTB > 0, secFormat.format(DTB)) +
      ", " + SDIR +
      ", " + xyzFormat.format(RPA) +
      ", " + xyzFormat.format(RPO) +
      ", " + xyzFormat.format(RPAP) +
      ", " + xyzFormat.format(POSS) + ")"
    );
    break;
  case "back-boring":
    expandCurrentCycle = true;
    break;
  case "manual-boring":
    writeBlock(
      "MCALL CYCLE88(" + xyzFormat.format(RTP) +
      ", " + xyzFormat.format(RFP) +
      ", " + xyzFormat.format(SDIS) +
      ", " + xyzFormat.format(DP) +
      ", " /*+ xyzFormat.format(DPR)*/ +
      ", " + conditional(DTB > 0, secFormat.format(DTB)) +
      ", " + SDIR + ")"
    );
    break;
  case "boring":
    // retract feed is ignored
    writeBlock(
      "MCALL CYCLE89(" + xyzFormat.format(RTP) +
      ", " + xyzFormat.format(RFP) +
      ", " + xyzFormat.format(SDIS) +
      ", " + xyzFormat.format(DP) +
      ", " /*+ xyzFormat.format(DPR)*/ +
      ", " + conditional(DTB > 0, secFormat.format(DTB)) + ")"
    );
    break;
  default:
    expandCurrentCycle = true;
  }
  if (!expandCurrentCycle) {
    xOutput.reset();
    yOutput.reset();
  }
}

function onCyclePoint(x, y, z) {
  if (!expandCurrentCycle) {
    var _x = xOutput.format(x);
    var _y = yOutput.format(y);
    /*zOutput.format(z)*/
    if (_x || _y) {
      writeBlock(_x, _y);
    }
  } else {
    expandCyclePoint(x, y, z);
  }
}

function onCycleEnd() {
  if (!expandCurrentCycle) {
    writeBlock("MCALL"); // end modal cycle
  }
  zOutput.reset();
  var start = getCurrentPosition();
  onLinear(start.x, start.y, start.z, feedOutput.getCurrent());
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
      return;
    }
    writeBlock(gMotionModal.format(0), x, y, z);
    feedOutput.reset();
  }
}

function onLinear(_x, _y, _z, feed) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = feedOutput.format(feed);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;

      if (tool.diameterOffset != 0) {
        warningOnce(localize("Diameter offset is not supported."), WARNING_DIAMETER_OFFSET);
      }

      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        writeBlock(gPlaneModal.format(17));
        writeBlock(gMotionModal.format(1), gFormat.format(41), x, y, z, f);
        break;
      case RADIUS_COMPENSATION_RIGHT:
        writeBlock(gPlaneModal.format(17));
        writeBlock(gMotionModal.format(1), gFormat.format(42), x, y, z, f);
        break;
      default:
        writeBlock(gMotionModal.format(1), gFormat.format(40), x, y, z, f);
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
    return;
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
    var x = xOutput.format(_x);
    var y = yOutput.format(_y);
    var z = zOutput.format(_z);
    var a3 = a3Output.format(_a);
    var b3 = b3Output.format(_b);
    var c3 = c3Output.format(_c);
    writeBlock(gMotionModal.format(0), x, y, z, a3, b3, c3);
  }
  feedOutput.reset();
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for 5-axis move."));
    return;
  }
  
  if (machineConfiguration.isMultiAxisConfiguration()) {
    var x = xOutput.format(_x);
    var y = yOutput.format(_y);
    var z = zOutput.format(_z);
    var a = aOutput.format(_a);
    var b = bOutput.format(_b);
    var c = cOutput.format(_c);
    var f = feedOutput.format(feed);
    if (x || y || z || a || b || c) {
      writeBlock(gMotionModal.format(1), x, y, z, a, b, c, f);
    } else if (f) {
      if (getNextRecord().isMotion()) { // try not to output feed without motion
        feedOutput.reset(); // force feed on next line
      } else {
        writeBlock(gMotionModal.format(1), f);
      }
    }
  } else {
    var x = xOutput.format(_x);
    var y = yOutput.format(_y);
    var z = zOutput.format(_z);
    var a3 = a3Output.format(_a);
    var b3 = b3Output.format(_b);
    var c3 = c3Output.format(_c);
    var f = feedOutput.format(feed);
    if (x || y || z || a || b || c) {
      writeBlock(gMotionModal.format(1), x, y, z, a3, b3, c3, f);
    } else if (f) {
      if (getNextRecord().isMotion()) { // try not to output feed without motion
        feedOutput.reset(); // force feed on next line
      } else {
        writeBlock(gMotionModal.format(1), f);
      }
    }
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  var start = getCurrentPosition();
  var turns = useArcTurn ? Math.floor(Math.abs(getCircularSweep())/(2 * Math.PI)) : 0; // full turns

  if (isFullCircle()) {
    if (isHelical()) {
      linearize(tolerance);
      return;
    }
    if (turns > 1) {
      error(localize("Multiple turns are not supported."));
      return;
    }
    // G90/G91 are dont care when we do not used XYZ
    switch (getCircularPlane()) {
    case PLANE_XY:
      if (radiusCompensation != RADIUS_COMPENSATION_OFF) {
        if ((gPlaneModal.getCurrent() != null) && (gPlaneModal.getCurrent() != 17)) {
          error(localize("Plane cannot be changed when radius compensation is active."));
          return;
        }
      }
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      break;
    case PLANE_ZX:
      if (radiusCompensation != RADIUS_COMPENSATION_OFF) {
        if ((gPlaneModal.getCurrent() != null) && (gPlaneModal.getCurrent() != 18)) {
          error(localize("Plane cannot be changed when radius compensation is active."));
          return;
        }
      }
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    case PLANE_YZ:
      if (radiusCompensation != RADIUS_COMPENSATION_OFF) {
        if ((gPlaneModal.getCurrent() != null) && (gPlaneModal.getCurrent() != 19)) {
          error(localize("Plane cannot be changed when radius compensation is active."));
          return;
        }
      }
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else {
    switch (getCircularPlane()) {
    case PLANE_XY:
      if (radiusCompensation != RADIUS_COMPENSATION_OFF) {
        if ((gPlaneModal.getCurrent() != null) && (gPlaneModal.getCurrent() != 17)) {
          error(localize("Plane cannot be changed when radius compensation is active."));
          return;
        }
      }
      // arFormat.format(Math.abs(getCircularSweep()));
      if (turns > 0) {
        writeBlock(gAbsIncModal.format(90), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed), "TURN=" + turns);
      } else {
        writeBlock(gAbsIncModal.format(90), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      }
      break;
    case PLANE_ZX:
      if (radiusCompensation != RADIUS_COMPENSATION_OFF) {
        if ((gPlaneModal.getCurrent() != null) && (gPlaneModal.getCurrent() != 18)) {
          error(localize("Plane cannot be changed when radius compensation is active."));
          return;
        }
      }
      if (turns > 0) {
        writeBlock(gAbsIncModal.format(90), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed), "TURN=" + turns);
      } else {
        writeBlock(gAbsIncModal.format(90), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      }
      break;
    case PLANE_YZ:
      if (radiusCompensation != RADIUS_COMPENSATION_OFF) {
        if ((gPlaneModal.getCurrent() != null) && (gPlaneModal.getCurrent() != 19)) {
          error(localize("Plane cannot be changed when radius compensation is active."));
          return;
        }
      }
      if (turns > 0) {
        writeBlock(gAbsIncModal.format(90), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed), "TURN=" + turns);
      } else {
        writeBlock(gAbsIncModal.format(90), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      }
      break;
    default:
      if (turns > 1) {
        error(localize("Multiple turns are not supported."));
        return;
      }
      if (true) { // allow CIP
        var ip = getPositionU(0.5);
        writeBlock(
          gAbsIncModal.format(90), "CIP",
          xOutput.format(x),
          yOutput.format(y),
          zOutput.format(z),
          "I1=" + xyzFormat.format(ip.x),
          "J1=" + xyzFormat.format(ip.y),
          "K1=" + xyzFormat.format(ip.z),
          feedOutput.format(feed)
        );
        gMotionModal.reset();
      } else {
        linearize(tolerance);
      }
    }
  }
}

var currentCoolantMode = undefined;

function forceCoolant() {
  currentCoolantMode = undefined;
}

function setCoolant(coolant) {
  if (coolant == currentCoolantMode) {
    return; // coolant is already active
  }
  
  var m;
  switch (coolant) {
  case COOLANT_OFF:
    m = 9;
    break;
  case COOLANT_FLOOD:
    m = 8;
    break;
  default:
    onUnsupportedCoolant(coolant);
    m = 9;
  }
  
  if (m) {
    writeBlock(mFormat.format(m));
    currentCoolantMode = coolant;
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
  COMMAND_LOAD_TOOL:6
};

function onCommand(command) {
  switch (command) {
  case COMMAND_COOLANT_OFF:
    setCoolant(COOLANT_OFF);
    return;
  case COMMAND_COOLANT_ON:
    setCoolant(COOLANT_FLOOD);
    return;
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
  if (currentSection.isMultiAxis()) {
    writeBlock("TRAFOOF");
  }
  writeBlock(gPlaneModal.format(17));
  forceAny();
}

function onClose() {
  writeBlock(gMotionModal.format(0), "SUPA", "Z" + machineConfiguration.getRetractPlane(), "D0"); // retract

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
    writeBlock(
      gMotionModal.format(0), "SUPA", homeX, homeY
    );
  }

  onImpliedCommand(COMMAND_END);
  onImpliedCommand(COMMAND_STOP_SPINDLE);
  writeBlock(mFormat.format(30)); // stop program, spindle stop, coolant off
}
