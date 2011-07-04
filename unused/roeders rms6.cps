/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  ROEDERS RMS6 post processor configuration.

  $Revision: 25831 $
  $Date: 2011-06-20 02:01:39 +0200 (ma, 20 jun 2011) $
  
  FORKID {A1016E8F-4BC1-43b0-93EB-88CFDC74F7DD}
*/

description = "Generic Roeders RMS6";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;
minimumRevision = 24000;

extension = "tap";
setCodePage("ascii");

tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = undefined; // allow any circular motion



// user-defined properties
properties = {
  graphite: true, // graphite if true and steel otherwise
  RMAX: spatial(2, MM), // RMAX value in millimeters only for finishing strategies
  cleanAir: true, // clean tool using air
  diameterDiff: 0.15, // tolerence diameter for measurement
  tipDiff: 0.1, // tolerence corner radius for measurement
  toolMeasurementOffset: 0.05, // the height offset above the tool corner for measuring the tool diameter  
  writeMachine: true, // write machine
  writeTools: true, // writes the tools
  preloadTool: false, // preloads next tool on tool change if any
  showSequenceNumbers: false, // show sequence numbers
  sequenceNumberStart: 10, // first sequence number
  sequenceNumberIncrement: 5, // increment for sequence numbers
  optionalStop: false, // optional stop
  overrideLengthOffset: -1, // overrides the length offset is positive by adding this number to the tool number (-1 for disabled)
  overrideDiameterOffset: -1, // overrides the diameter offset is positive by adding this number to the tool number (-1 for disabled)
  allowArcs: false, // set to true to output arcs
  separateWordsWithSpace: true // specifies that the words should be separated with a white space
};



var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,=_-";

var mapSteelCoolantTable = new Table(
  ["CLEANOFF", "CLEANON", "CLEANON", "CLEANON", "CLEANON", "CLEANON"],
  {initial:COOLANT_OFF, force:true},
  "Invalid coolant mode"
);

var mapGraphiteCoolantTable = new Table(
  ["CLEANOFF", "CLEANON", "CLEANON", "CLEANON", "CLEANON", "CLEANON"],
  {initial:COOLANT_OFF, force:true},
  "Invalid coolant mode"
);

var gFormat = createFormat({prefix:"G"});
var mFormat = createFormat({prefix:"M"});
var hFormat = createFormat({prefix:"H"});

var xyzFormat = createFormat({decimals:(unit == MM ? 4 : 5), forceDecimal:true});
var abcFormat = createFormat({decimals:3, forceDecimal:true});
var feedFormat = createFormat({decimals:(unit == MM ? 0 : 1), forceDecimal:true, scale:(unit == MM ? 1 : 25.4)});
var motionFormat = createFormat({decimals:6, forceDecimal:true});

var toolDmCrFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, trim:false, width:6});
var toolListFormat = createFormat({decimals:0, width:4});

var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3, forceDecimal:true}); // seconds - range 0.001-99999.999
var taperFormat = createFormat({decimals:1, width:3, scale:DEG});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);
var aOutput = createVariable({prefix:"A"}, abcFormat);
var bOutput = createVariable({prefix:"B"}, abcFormat);
var cOutput = createVariable({prefix:"C"}, abcFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var sOutput = createVariable({prefix:"S", force:true}, rpmFormat);

// circular output
var iOutput = createReferenceVariable({prefix:"I"}, xyzFormat);
var jOutput = createReferenceVariable({prefix:"J"}, xyzFormat);
var kOutput = createReferenceVariable({prefix:"K"}, xyzFormat);

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G93-94
var gUnitModal = createModal({}, gFormat); // modal group 6 // G70-71
var gCycleModal = createModal({}, gFormat); // modal group 9 // G81, ...
var gRetractModal = createModal({}, gFormat); // modal group 10 // G98-99

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

function writeSeparator() {
  writeln("");
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln("// " + filterText(text.toUpperCase(), permittedCommentChars));
}

function onOpen() {

  if (false) { // note: setup your machine here
    var bAxis = createAxis({coordinate:1, table:false, axis:[0, 1, 0], range:[-360,360], preference:1});
    var cAxis = createAxis({coordinate:2, table:false, axis:[0, 0, 1], range:[-360,360], preference:1});
    machineConfiguration = new MachineConfiguration(bAxis, cAxis);

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
  
  if (!properties.separateWordsWithSpace) {
    setWordSeparator("");
  }

  sequenceNumber = properties.sequenceNumberStart;
  if (programName) {
    writeComment("" + programName);
  } else {
    error(localize("Program name has not been specified."));
  }
  if (programComment) {
    writeComment("" + programComment);
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
  
  writeSeparator();
     
  // dump tool information
  if (properties.writeTools) {
    var tools = getToolTable();
    if (tools.getNumberOfTools() > 0) {
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
    }
    
    for (var D=localize("D"); D.length<=5; D = " " + D);
    for (var CR=localize("CR"); CR.length<=5; CR = " " + CR);
    for (var Taper=localize("TAPER"); Taper.length<=7; Taper = " " + Taper);
    for (var type=localize("Type"); type.length<=19; type += " ");
    for (var deg=localize("deg"); deg.length<=3; deg += " ");
    for (var SP1=""; SP1.length<=3; SP1 += "-");
    for (var SP2=""; SP2.length<=5; SP2 += "-");
    for (var SP3=""; SP3.length<=5; SP3 += "-");
    for (var SP4=""; SP4.length<=7; SP4 += "-");
    for (var SP5=""; SP5.length<=19; SP5 += "-");
    for (var SP6=""; SP6.length<=6; SP6 += "-");
    
    writeBlock("/*");
    writeBlock("     " + "T" + " | " + D + " | " + CR + " | " + Taper + " | " + type + " | " + localize("ZMIN"));
    writeBlock("  " + SP1 +" | " + SP2 +" | " + SP3 +" | " + SP4 +" | " + SP5 +" | " + SP6);
    for (var i = 0; i < tools.getNumberOfTools(); ++i) {
      var tool = tools.getTool(i);
      for (var m = getToolTypeName(tool.type); m.length <= 19; m += " ");
      writeBlock(
        "  " + toolListFormat.format(tool.number) + " | " +
        toolDmCrFormat.format(tool.diameter) + " | " +
        toolDmCrFormat.format(tool.cornerRadius) + " | " +
        taperFormat.format(tool.taperAngle) + " " + deg + " | " +
        m + " | " +
        (zRanges[tool.number] ? toolDmCrFormat.format(zRanges[tool.number].getMinimum()) : "")
      );
    }
    writeSeparator();

    { // stock - workpiece
      var delta = Vector.diff(workpieceUpper, workpieceLower);
      if (delta.isNonZero()) {
        writeBlock("Work piece: DX: " + toolDmCrFormat.format(delta.x) + "  DY: " + toolDmCrFormat.format(delta.y) + "  DZ: " + toolDmCrFormat.format(delta.z));
        writeBlock("Work piece min: X " + xyzFormat.format(workpieceLower.x) + " Y " + xyzFormat.format(workpieceLower.y) + " Z " + xyzFormat.format(workpieceLower.z));
        writeBlock("Work piece max: X " + xyzFormat.format(workpieceUpper.x) + " Y " + xyzFormat.format(workpieceUpper.y) + " Z " + xyzFormat.format(workpieceUpper.z));
      }
    }
    writeBlock("*/");
  }
   
  writeSeparator();
  writeBlock("VAR $MeasureBeforeToolChange=0 // 1=always measure before tool change");
  writeSeparator();
  writeBlock("MACOOR -all"); // reset

  // absolute coordinates and feed per min
  writeBlock(gAbsIncModal.format(90), gFeedModeModal.format(94));
  changePlane(17);

  switch (unit) {
  case IN:
    writeBlock(gUnitModal.format(70));
    break;
  case MM:
    writeBlock(gUnitModal.format(71));
    break;
  }
  
  writeSeparator();
  writeBlock('LOADZERO=""', " -h=0");
  writeSeparator();
  
  if (properties.graphite) {
    writeBlock("VACON");
  }
  
  writeBlock("CCI");

  // writeBlock("HEADEREND");
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

function onSection() {
  var insertToolCall = isFirstSection() || (tool.number != getPreviousSection().getTool().number);
  
  if (isFirstSection() || insertToolCall) {
    // retract to safe plane
    writeBlock("SH"); // retract
    zOutput.reset();
  }
  
  var RADMAX;
  var SM;
  var RMAX;
  var toleranceOperation = hasParameter("operation:tolerance") ? getParameter("operation:tolerance") : 0;
  var stockToLeave = hasParameter("operation:stockToLeave") ? getParameter("operation:stockToLeave") : 0;
  var axialStockToLeave = hasParameter("operation:verticalStockToLeave") ? getParameter("operation:verticalStockToLeave") : 0;
  
  var TOL = toleranceOperation * 2;
    
  switch (getParameter("operation:strategy")) {
  case "face":
    RMAX = 3;
    RADMAX = 100;
    SM = 0;
    break;
  case "drill":
    RMAX = 3;
    RADMAX = 100;
    SM = 0;
    break;
  case "contour2d":
    RMAX = properties.RMAX;
    RADMAX = 5000;
    SM = 0;
    break;
  case "pocket2d":
    if (tool.diameter >= 3) {
      RMAX = 7;
    } else if ((tool.diameter < 3) && (tool.diameter > 1)) {
      RMAX = 5;
    } else if (tool.diameter <= 1) {
      RMAX = 3;
    } else {
      RMAX = 4;
    }
    RADMAX = 3000;
    SM = stockToLeave / 3;
    if (SM < 0) {
      SM = 0;
    }
    break;
  case "adaptive2d":
    if (tool.diameter >= 3) {
      RMAX = 7;
    } else if ((tool.diameter < 3) && (tool.diameter > 1)) {
      RMAX = 5;
    } else if (tool.diameter <= 1) {
      RMAX = 3;
    } else {
      RMAX = 4;
    }
    RADMAX = 3000;
    SM = stockToLeave / 3;
    if (SM < 0) {
      SM = 0;
    } 
    break;
  case "path3d":
    RMAX = properties.RMAX;
    RADMAX = 3000;
    SM = 0;
    break;
  case "pocket_new":
    if (tool.diameter >= 3) {
      RMAX = 7;
    } else if ((tool.diameter < 3) && (tool.diameter > 1)) {
      RMAX = 5;
    } else if (tool.diameter <= 1) {
      RMAX = 3;
    } else {
      RMAX = 4;
    }
    RADMAX = 3000;
    SM = stockToLeave / 3;
    if (SM < 0) {
      SM = 0;
    }
    break;
  case "adaptive":
    if (tool.diameter >= 3) {
      RMAX = 7;
    } else if ((tool.diameter < 3) && (tool.diameter > 1)) {
      RMAX = 5;
    } else if (tool.diameter <= 1) {
      RMAX = 3;
    } else {
      RMAX = 4;
    } 
    RADMAX = 3000;
    SM = stockToLeave / 3;
    if (SM < 0) {
      SM = 0;
    }
    break;
  case "horizontal_new":
    RMAX = properties.RMAX;
    RADMAX = 100;
    SM = 0;
    break;
  case "contour_new":
    RMAX = properties.RMAX;
    RADMAX = 5000;
    SM = 0;
    break;
  case "parallel_new":
    RMAX = properties.RMAX;
    RADMAX = 8000;
    SM = 0;
    break;
  case "pencil_new":
    RMAX = properties.RMAX;
    RADMAX = 5000;
    SM = 0;
    break;
  case "scallop_new":
    RMAX = properties.RMAX;
    RADMAX = 6000;
    SM = 0;
    break;
  case "radial_new":
    RMAX = properties.RMAX;
    RADMAX = 6000;
    SM = 0;
    break;
  case "spiral_new":
    RMAX = properties.RMAX;
    RADMAX = 6000;
    SM = 0;
    break;
  case "project":
    RMAX = properties.RMAX;
    RADMAX =  3000;
    SM = 0;
    break;
  default:
    RMAX = 2;
    RADMAX = 3000;
    SM = 0;
  }	  

  if (insertToolCall) {
    //onCommand(COMMAND_COOLANT_OFF);
  
    if (!isFirstSection() && properties.optionalStop) {
      onCommand(COMMAND_OPTIONAL_STOP);
    }

    if (tool.number > 99) {
      warning(localize("Tool number exceeds maximum value."));
    }
    
    writeBlock(
      "T" + toolFormat.format(tool.number), mFormat.format(6) + " // " + localize("D") + toolDmCrFormat.format(tool.diameter) + " | " +
      localize("CR") + ":" + toolDmCrFormat.format(tool.cornerRadius) + " | " +
      localize("TAPER") + ":" + taperFormat.format(tool.taperAngle) + " " +
      localize("deg") + " | " + getToolTypeName(tool.type)
    );
    if (tool.comment) {
      writeComment(tool.comment);
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
  
  var offset = 0;
  switch (tool.type) {
  case TOOL_MILLING_END_FLAT:
  case TOOL_MILLING_END_BULLNOSE:
    // TAG: add support for taper tool
    switch (unit) {
    case MM:
      offset = tool.diameter/2 - tool.cornerRadius - properties.toolMeasurementOffset;
      break;
    case IN:
      offset = tool.diameter/2 - tool.cornerRadius - properties.toolMeasurementOffset/25.4;
      break;
    }
    if (offset < 0) {
      offset = 0;
    }
    break;
  } 
  
  if (insertToolCall) {
    writeSeparator();	  
    writeBlock("IF (($L_ < 0.01) or ($MeasureBeforeToolChange == 1))");
    if (properties.cleanAir) {
      writeBlock("  CTAIR");
    }
    writeBlock("  TDM=" + xyzFormat.format(tool.cornerRadius + properties.toolMeasurementOffset), "-r=" + xyzFormat.format(offset), "-clean");
    writeBlock("ENDIF");
    writeBlock("TLC", "-auto"); // compensate tool length
    writeBlock("CheckTool", "-D=" + xyzFormat.format(tool.diameter), "-TD=" + properties.diameterDiff); // writeBlock("CheckTool", "-D=" + xyzFormat.format(tool.diameter), "-TD=" + properties.diameterDiff, "-RE=" + xyzFormat.format(tool.cornerRadius), "-TRE=" + properties.tipDiff, "-act");
  }
  
  writeSeparator();
  writeBlock("RMAX=" + motionFormat.format(RMAX), "TOL=" + motionFormat.format(TOL), "SM=" + motionFormat.format(SM), "RADMAX=" + motionFormat.format(RADMAX));
  writeSeparator();
  
  // wcs
  if (currentSection.workOffset > 0) {
    warning(localize("Work offset is ignored."));
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

  // set coolant after we have positioned at Z
  {
    var c;
    if (properties.graphite) {
      c = mapGraphiteCoolantTable.lookup(tool.coolant);
    } else {
      c = mapSteelCoolantTable.lookup(tool.coolant);
    }
    if (c) {
      writeBlock(c);
    } else {
      warning(localize("Coolant not supported."));
    }
  }

  forceAny();
  gMotionModal.reset();

  var lengthOffset = (properties.overrideLengthOffset >= 0) ? (tool.number + properties.overrideLengthOffset) : tool.lengthOffset;
  if (lengthOffset > 99) {
    error(localize("Length offset out of range."));
  }

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (getCurrentPosition().z <= initialPosition.z) {
    // position in Z first since we do not do machine retracts
    writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
    writeBlock(
      gAbsIncModal.format(90),
      gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y)
    );
  } else {
    writeBlock(
      gAbsIncModal.format(90),
      gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y)
    );
    writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
  }
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  writeBlock("WAIT=" + secFormat.format(seconds));
}

function onCyclePoint(x, y, z) {
  expandCyclePoint(x, y, z);
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

var mapRapidToHighFeed = false;

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    }
    if (mapRapidToHighFeed) {
      writeBlock(gMotionModal.format(1), x, y, z, feedOutput.format(highFeedrate));
    } else {
      writeBlock(gMotionModal.format(0), x, y, z);
      feedOutput.reset();
    }
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
      var d = (properties.overrideDiameterOffset >= 0) ? (tool.number + properties.overrideDiameterOffset) : tool.diameterOffset;
      if (d > 99) {
        warning(localize("The diameter offset exceeds the maximum value."));
      }
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        changePlane(17);
        writeBlock(gMotionModal.format(1), gFormat.format(41), x, y, z, f);
        break;
      case RADIUS_COMPENSATION_RIGHT:
        changePlane(17);
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
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var a = aOutput.format(_a);
  var b = bOutput.format(_b);
  var c = cOutput.format(_c);
  writeBlock(gMotionModal.format(0), x, y, z, a, b, c);
  feedOutput.reset();
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  if (pendingRadiusCompensation >= 0) {
    error("Radius compensation cannot be activated/deactivated for 5-axis move.");
  }

  forceXYZ();
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
}

function changePlane(planeCode) {
  var g = gPlaneModal.format(planeCode);
  if (g) {
    var start = getCurrentPosition();
    var x = xOutput.format(start.x);
    var y = yOutput.format(start.y);
    if (!x && !y) { // force at least one coordiante
      zOutput.reset();
    }
    var z = zOutput.format(start.z);
    writeBlock(g, gMotionModal.format(1), x, y, z);
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (pendingRadiusCompensation >= 0) {
    error("Radius compensation cannot be activated/deactivated for a circular move.");
  }

  if (!properties.allowArcs) {
    var t = tolerance;
    if (hasParameter("operation:tolerance")) {
      t = Math.min(t, getParameter("operation:tolerance"));
    }
    linearize(t);
    return;
  }

  var start = getCurrentPosition();

  if (isFullCircle()) {
    switch (getCircularPlane()) {
    case PLANE_XY:
      changePlane(17);
      var G = gMotionModal.format(clockwise ? 2 : 3);
      writeBlock(gAbsIncModal.format(90), G, iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      break;
    case PLANE_ZX:
      changePlane(18);
      var G = gMotionModal.format(clockwise ? 2 : 3);
      writeBlock(gAbsIncModal.format(90), G, iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    case PLANE_YZ:
      changePlane(19);
      var G = gMotionModal.format(clockwise ? 2 : 3);
      writeBlock(gAbsIncModal.format(90), G, jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    default:
      var t = tolerance;
      if (hasParameter("operation:tolerance")) {
        t = Math.min(t, getParameter("operation:tolerance"));
      }
      linearize(t);
    }
  } else {
    switch (getCircularPlane()) {
    case PLANE_XY:
      changePlane(17);
      var G = gMotionModal.format(clockwise ? 2 : 3);
      writeBlock(gAbsIncModal.format(90), G, xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      break;
    case PLANE_ZX:
      changePlane(18);
      var G = gMotionModal.format(clockwise ? 2 : 3);
      writeBlock(gAbsIncModal.format(90), G, xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    case PLANE_YZ:
      changePlane(19);
      var G = gMotionModal.format(clockwise ? 2 : 3);
      writeBlock(gAbsIncModal.format(90), G, xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    default:
      var t = tolerance;
      if (hasParameter("operation:tolerance")) {
        t = Math.min(t, getParameter("operation:tolerance"));
      }
      linearize(t);
    }
  }
}

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
  case COMMAND_COOLANT_ON:
    writeBlock(properties.graphite ? "CLEANON" : "CLEANON");
    return;
  case COMMAND_COOLANT_OFF:
    writeBlock(properties.graphite ? "CLEANOFF" : "CLEANOFF");
    return;
  case COMMAND_SPINDLE_CLOCKWISE:
    writeBlock("SPINON");
    return;
  case COMMAND_STOP_SPINDLE:
    writeBlock("SPINOFF");
    return;
  case COMMAND_OPTIONAL_STOP:
    writeBlock("WAITC");
    return;
  }

  onUnsupportedCommand(command);
}

function onSectionEnd() {
  forceAny();

  switch (unit) {
  case MM:
    offset = tool.diameter/2 - tool.cornerRadius - properties.toolMeasurementOffset;	
    break;
  case IN:
    offset = tool.diameter/2 - tool.cornerRadius - properties.toolMeasurementOffset/25.4;
    break;
  }
  if (offset < 0) {
    offset = 0;
  } 

  // only tool measurement if the next tool is another one,
  // or the current tool is the last one
    
  if (!hasNextSection() || (getNextSection().getTool().number != tool.number)) {
   if (properties.cleanAir) {
     writeBlock("CTAIR");
   }
   writeBlock("TLM -FAST");
   writeBlock("TDM=" + xyzFormat.format(tool.cornerRadius + properties.toolMeasurementOffset), "-r=" + xyzFormat.format(offset), "-clean");
  }

  changePlane(17);
  forceAny();
}

function onClose() {
  onCommand(COMMAND_COOLANT_OFF);

  // clearance height must be high enough
  writeBlock("SH"); // retract
  zOutput.reset();

  if (!machineConfiguration.hasHomePositionX() && !machineConfiguration.hasHomePositionY()) {
    // no home position
  } else {
    var homeX;
    if (machineConfiguration.hasHomePositionX()) {
      homeX = "X" + xyzFormat.format(machineConfiguration.getHomePositionX());
    }
    var homeY;
    if (machineConfiguration.hasHomePositionY()) {
      homeY = "Y" + xyzFormat.format(machineConfiguration.getHomePositionY());
    }
    // writeBlock(gAbsIncModal.format(90), gMotionModal.format(0), homeX, homeY);
  }

  onCommand(COMMAND_STOP_SPINDLE);
  
  if (properties.graphite) {
    writeBlock("VACOFF");
  }

  onImpliedCommand(COMMAND_END);
  writeBlock(mFormat.format(30)); // end program
}
