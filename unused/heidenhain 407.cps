/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Heidenhain post processor configuration.

  $Revision: 25624 $
  $Date: 2011-06-03 20:34:52 +0200 (fr, 03 jun 2011) $
  
  FORKID {E3B36C97-FF8E-483a-B063-3F7E73B62424}
*/

description = "Heidenhain TNC 407";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;
minimumRevision = 24000;

extension = "h";
if (getCodePage() == 932) { // shift-jis is not supported
  setCodePage("ascii");
} else {
  setCodePage("ansi"); // setCodePage("utf-8");
}

tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(5400); // 15 revolutions
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion



// user-defined properties
properties = {
  writeMachine: false, // write machine
  writeTools: true, // writes the tools
  preloadTool: false, // preloads next tool on tool change if any
  expandCycles: true, // expands unhandled cycles
  rigidTapping: true, // rigid tapping
  optionalStop: true, // optional stop
  structureComments: false, // show structure comments
  useM92: false, // use M92 instead of M91
  useFeedQ: false // specifies that feed should be output using Q values
};



var WARNING_WORK_OFFSET = 0;

// collected state
var blockNumber = 0;
var activeMovements; // do not use by default
var workOffsetLabels = {};
var nextLabel = 1;

var spindleAxisTable = new Table(["X", "Y", "Z"], {force:true});

var radiusCompensationTable = new Table(
  [" R0", " RL", " RR"],
  {initial:RADIUS_COMPENSATION_OFF},
  "Invalid radius compensation"
);

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceSign:true});
var abcFormat = createFormat({decimals:3, forceSign:true, scale:DEG});
var feedFormat = createFormat({decimals:(unit == MM ? 0 : 2)});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3});
var paFormat = createFormat({decimals:3, forceSign:true, scale:DEG});
var angleFormat = createFormat({decimals:0, scale:DEG});
var pitchFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceSign:true});
var mFormat = createFormat({prefix:"M", decimals:0});

// presentation formats
var spatialFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var taperFormat = angleFormat; // share format

var xOutput = createVariable({prefix:" X"}, xyzFormat);
var yOutput = createVariable({prefix:" Y"}, xyzFormat);
var zOutput = createVariable({prefix:" Z"}, xyzFormat);
var aOutput = createVariable({prefix:" A"}, abcFormat);
var bOutput = createVariable({prefix:" B"}, abcFormat);
var cOutput = createVariable({prefix:" C"}, abcFormat);
var feedOutput = createVariable({prefix:" F"}, feedFormat);

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/**
  Writes the specified block.
*/
function writeBlock(block) {
  writeln(blockNumber + SP + block);
  ++blockNumber;
}

/**
  Writes the specified block as optional.
*/
function writeOptionalBlock(block) {
  writeln("/" + blockNumber + SP + block);
  ++blockNumber;
}

/** Output a comment. */
function writeComment(text) {
  if (isTextSupported(text)) {
    writeln(blockNumber + SP + "; " + text); // some controls may require a block number
    ++blockNumber;
  }
}

/** Adds a structure comment. */
function writeStructureComment(text) {
  if (properties.structureComments) {
    if (isTextSupported(text)) {
      writeBlock("* - " + text);
    }
  }
}

/** Writes a separator. */
function writeSeparator() {
  writeComment("-------------------------------------");
}

/** Writes the specified text through the data interface. */
function printData(text) {
  if (isTextSupported(text)) {
    writeln("FN15: PRINT " + text);
  }
}

function onOpen() {

  // NOTE: setup your machine here
  if (false) {
    //var aAxis = createAxis({coordinate:0, table:true, axis:[1, 0, 0], range:[-120.0001,120.0001], preference:1});
    //var bAxis = createAxis({coordinate:1, table:true, axis:[0, 1, 0], range:[-120.0001,120.0001], preference:1});
    //var cAxis = createAxis({coordinate:2, table:true, axis:[0, 0, 1], range:[10*-360,10*360], preference:1});
    //machineConfiguration = new MachineConfiguration(bAxis, cAxis);
  
    machineConfiguration = new MachineConfiguration();

    setMachineConfiguration(machineConfiguration);
    optimizeMachineAngles2(0); // using M128 mode
  }

  writeBlock(
    "BEGIN PGM" + (programName ? (SP + programName) : "") + ((unit == MM) ? " MM" : " INCH")
  );
  if (programComment) {
    writeComment(programComment);
  }

  { // stock - workpiece
    var workpiece = getWorkpiece();
    var delta = Vector.diff(workpiece.upper, workpiece.lower);
    if (delta.isNonZero()) {
      writeBlock("BLK FORM 0.1 Z X" + xyzFormat.format(workpiece.lower.x) + " Y" + xyzFormat.format(workpiece.lower.y) + " Z" + xyzFormat.format(workpiece.lower.z));
      writeBlock("BLK FORM 0.2 X" + xyzFormat.format(workpiece.upper.x) + " Y" + xyzFormat.format(workpiece.upper.y) + " Z" + xyzFormat.format(workpiece.upper.z));
    }
  }

  // dump machine configuration
  var vendor = machineConfiguration.getVendor();
  var model = machineConfiguration.getModel();
  var description = machineConfiguration.getDescription();

  if (properties.writeMachine && (vendor || model || description)) {
    writeSeparator();
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
    writeSeparator();
    writeComment("");
  }

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

      writeSeparator();
      writeComment(localize("Tools"));
      for (var i = 0; i < tools.getNumberOfTools(); ++i) {
        var tool = tools.getTool(i);
        var comment = "  #" + tool.number + " " +
          localize("D") + "=" + spatialFormat.format(tool.diameter) +
          conditional(tool.cornerRadius > 0, " " + localize("CR") + "=" + spatialFormat.format(tool.cornerRadius)) +
          conditional((tool.taperAngle > 0) && (tool.taperAngle < Math.PI), " " + localize("TAPER") + "=" + taperFormat.format(tool.taperAngle) + localize("deg"));
          // conditional(tool.tipAngle > 0, " " + localize("TIP:") + "=" + taperFormat.format(tool.tipAngle) + localize("deg"));
        if (zRanges[tool.number]) {
          comment += " - " + localize("ZMIN") + "=" + xyzFormat.format(zRanges[tool.number].getMinimum());
          comment += " - " + localize("ZMAX") + "=" + xyzFormat.format(zRanges[tool.number].getMaximum());
        }
        comment += " - " + getToolTypeName(tool.type);
        writeComment(comment);
        if (tool.comment) {
          writeComment("    " + tool.comment);
        }
        if (tool.vendor) {
          writeComment("    " + tool.vendor);
        }
        if (tool.productId) {
          writeComment("    " + tool.productId);
        }
      }
      writeSeparator();
      writeComment("");
    }
  }
}

function onComment(message) {
  writeComment(message);
}

function invalidateXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

function forceFeed() {
  currentFeedId = undefined;
  feedOutput.reset();
}

/**
  Invalidates the current position and feedrate. Invoke this function to
  force X, Y, Z, A, B, C, and F in the following block.
*/
function invalidate() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
  aOutput.reset();
  bOutput.reset();
  cOutput.reset();
  forceFeed();
}

var currentTolerance = undefined;

function setTolerance(tolerance) {
  if (tolerance == currentTolerance) {
    return;
  }
  currentTolerance = tolerance;
}

function FeedContext(id, description, feed) {
  this.id = id;
  this.description = description;
  this.feed = feed;
}

/** Maps the specified feed value to Q feed or formatted feed. */
function getFeed(f) {
  if (activeMovements) {
    var feedContext = activeMovements[movement];
    if (feedContext != undefined) {
      if (!feedFormat.areDifferent(feedContext.feed, f)) {
        if (feedContext.id == currentFeedId) {
          return ""; // nothing has changed
        }
        currentFeedId = feedContext.id;
        feedOutput.reset();
        return " FQ" + (50 + feedContext.id);
      }
    }
    currentFeedId = undefined; // force Q feed next time
  }
  return feedOutput.format(f); // use feed value
}

function initializeActiveFeeds() {
  activeMovements = new Array();
  var movements = currentSection.getMovements();

  var id = 0;
  var activeFeeds = new Array();
  if (hasParameter("operation:tool_feedCutting")) {
    if (movements & (1 << MOVEMENT_CUTTING) | (1 << MOVEMENT_LINK_TRANSITION) | (1 << MOVEMENT_EXTENDED)) {
      var feedContext = new FeedContext(id, localize("Cutting"), getParameter("operation:tool_feedCutting"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_CUTTING] = feedContext;
      activeMovements[MOVEMENT_LINK_TRANSITION] = feedContext;
      activeMovements[MOVEMENT_EXTENDED] = feedContext;
    }
    ++id;
    if (movements & (1 << MOVEMENT_PREDRILL)) {
      feedContext = new FeedContext(id, localize("Predrilling"), getParameter("operation:tool_feedCutting"));
      activeMovements[MOVEMENT_PREDRILL] = feedContext;
      activeFeeds.push(feedContext);
    }
    ++id;
  }
  if (hasParameter("operation:tool_feedEntry")) {
    if (movements & (1 << MOVEMENT_LEAD_IN)) {
      var feedContext = new FeedContext(id, localize("Entry"), getParameter("operation:tool_feedEntry"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LEAD_IN] = feedContext;
    }
    ++id;
  }
  if (hasParameter("operation:tool_feedExit")) {
    if (movements & (1 << MOVEMENT_LEAD_OUT)) {
      var feedContext = new FeedContext(id, localize("Exit"), getParameter("operation:tool_feedExit"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LEAD_OUT] = feedContext;
    }
    ++id;
  }
  if (hasParameter("operation:noEngagementFeedrate")) {
    if (movements & (1 << MOVEMENT_LINK_DIRECT)) {
      var feedContext = new FeedContext(id, localize("Direct"), getParameter("operation:noEngagementFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LINK_DIRECT] = feedContext;
    }
    ++id;
  } else if (hasParameter("operation:tool_feedCutting") &&
             hasParameter("operation:tool_feedEntry") &&
             hasParameter("operation:tool_feedExit")) {
    if (movements & (1 << MOVEMENT_LINK_DIRECT)) {
      var feedContext = new FeedContext(id, localize("Direct"), Math.max(getParameter("operation:tool_feedCutting"), getParameter("operation:tool_feedEntry"), getParameter("operation:tool_feedExit")));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LINK_DIRECT] = feedContext;
    }
    ++id;
  }
  
  if (hasParameter("operation:finishFeedrate")) {
    if (movements & (1 << MOVEMENT_FINISH_CUTTING)) {
      var feedContext = new FeedContext(id, localize("Finish"), getParameter("operation:finishFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_FINISH_CUTTING] = feedContext;
    }
    ++id;
  } else if (hasParameter("operation:tool_feedCutting")) {
    if (movements & (1 << MOVEMENT_FINISH_CUTTING)) {
      var feedContext = new FeedContext(id, localize("Finish"), getParameter("operation:tool_feedCutting"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_FINISH_CUTTING] = feedContext;
    }
    ++id;
  }
/*
  if (hasParameter("operation:reducedFeedrate")) {
    if (movements & (1 << MOVEMENT_REDUCED)) {
      var feedContext = new FeedContext(id, localize("Reduced"), getParameter("operation:reducedFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_REDUCED] = feedContext;
    }
    ++id;
  }
*/

  if (hasParameter("operation:tool_feedRamp")) {
    if (movements & (1 << MOVEMENT_RAMP) | (1 << MOVEMENT_RAMP_HELIX) | (1 << MOVEMENT_RAMP_PROFILE) | (1 << MOVEMENT_RAMP_ZIG_ZAG)) {
      var feedContext = new FeedContext(id, localize("Ramping"), getParameter("operation:tool_feedRamp"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_RAMP] = feedContext;
      activeMovements[MOVEMENT_RAMP_HELIX] = feedContext;
      activeMovements[MOVEMENT_RAMP_PROFILE] = feedContext;
      activeMovements[MOVEMENT_RAMP_ZIG_ZAG] = feedContext;
    }
    ++id;
  }
  if (hasParameter("operation:tool_feedPlunge")) {
    if (movements & (1 << MOVEMENT_PLUNGE)) {
      var feedContext = new FeedContext(id, localize("Plunge"), getParameter("operation:tool_feedPlunge"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_PLUNGE] = feedContext;
    }
    ++id;
  }
  if (true) { // high feed
    if (movements & (1 << MOVEMENT_HIGH_FEED)) {
      var feedContext = new FeedContext(id, localize("High Feed"), this.highFeedrate);
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_HIGH_FEED] = feedContext;
    }
    ++id;
  }
  
  for (var i = 0; i < activeFeeds.length; ++i) {
    var feedContext = activeFeeds[i];
    writeBlock("FN0: Q" + (50 + feedContext.id) + "=" + feedFormat.format(feedContext.feed) + " ; " + feedContext.description);
  }
}

function onSection() {
  var insertToolCall = isFirstSection() ||
   (tool.number != getPreviousSection().getTool().number) ||
   (tool.spindleRPM != getPreviousSection().getTool().spindleRPM) ||
   (tool.clockwise != getPreviousSection().getTool().clockwise);

  if (insertToolCall) {
    setCoolant(COOLANT_OFF);
  }
  
  var retracted = false; // specifies that the tool has been retracted to the safe plane
  var newWorkPlane = isFirstSection() ||
    !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis());
  if (insertToolCall || newWorkPlane) {

    // retract to safe plane
    retracted = true;
    writeBlock("L Z" + xyzFormat.format(machineConfiguration.getRetractPlane()) + " R0 FMAX " + mFormat.format(properties.useM92 ? 92 : 91));
  }
  
  if (insertToolCall) {
    onCommand(COMMAND_STOP_SPINDLE);

    if (!isFirstSection() && properties.optionalStop) {
      onCommand(COMMAND_STOP_CHIP_TRANSPORT);
      onCommand(COMMAND_OPTIONAL_STOP);
    }

    if (!isFirstSection()) {
      onCommand(COMMAND_BREAK_CONTROL);
    }

    if (false) {
      var zRange = currentSection.getGlobalZRange();
      var numberOfSections = getNumberOfSections();
      for (var i = getCurrentSectionId() + 1; i < numberOfSections; ++i) {
        var section = getSection(i);
        var _tool = section.getTool();
        if (_tool.number != tool.number) {
          break;
        }
        zRange.expandToRange(section.getGlobalZRange());
      }

      writeStructureComment("T" + tool.number + "-D" + spatialFormat.format(tool.diameter) + "-CR:" + spatialFormat.format(tool.cornerRadius) + "-ZMIN:" + spatialFormat.format(zRange.getMinimum()) + "-ZMAX:" + spatialFormat.format(zRange.getMaximum()));
    }

    writeBlock(
      "TOOL CALL " + tool.number + SP + spindleAxisTable.lookup(spindleAxis) + " S" + rpmFormat.format(tool.spindleRPM)
    );
    if (tool.comment) {
      writeComment(tool.comment);
    }

    onCommand(COMMAND_TOOL_MEASURE);

    if (properties.preloadTool) {
      var nextTool = getNextTool(tool.number);
      if (nextTool) {
        writeBlock("TOOL DEF " + nextTool.number);
      } else {
        // preload first tool
        var section = getSection(0);
        var firstToolNumber = section.getTool().number;
        if (tool.number != firstToolNumber) {
          writeBlock("TOOL DEF " + firstToolNumber);
        }
      }
    }
    onCommand(COMMAND_START_CHIP_TRANSPORT);
  }

  onCommand(tool.clockwise ? COMMAND_SPINDLE_CLOCKWISE : COMMAND_SPINDLE_COUNTERCLOCKWISE);

  // wcs
  if (currentSection.workOffset > 0) {
    if (currentSection.workOffset > 9999) {
      error(localize("Work offset out of range."));
    }
    // datum shift after tool call
    writeBlock("CYCL DEF 7.0 " + localize("DATUM SHIFT"));
    writeBlock("CYCL DEF 7.1 #" + currentSection.workOffset);
  } else {
    warningOnce(localize("Work offset has not been specified."), WARNING_WORK_OFFSET);
  }

  {
    radiusCompensationTable.lookup(RADIUS_COMPENSATION_OFF);
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return;
    }
    setRotation(remaining);
  }
  
  invalidate();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
    
  if (!retracted) {
    if (getCurrentPosition().z < initialPosition.z) {
      writeBlock("L" + zOutput.format(initialPosition.z) + " FMAX");
    }
  }

  if (!machineConfiguration.isHeadConfiguration()) {
    writeBlock("L" + xOutput.format(initialPosition.x) + yOutput.format(initialPosition.y) + " R0 FMAX");
    z = zOutput.format(initialPosition.z);
    if (z) {
      writeBlock("L" + z + " R0 FMAX");
    }
  } else {
    writeBlock("L" + xOutput.format(initialPosition.x) + yOutput.format(initialPosition.y) + zOutput.format(initialPosition.z) + " R0 FMAX");
  }

  // set coolant after we have positioned at Z
  if (insertToolCall) {
    forceCoolant();
  }
  setCoolant(tool.coolant);

  if (hasParameter("operation-strategy") && (getParameter("operation-strategy") == "drill")) {
    setTolerance(0);
  } else if (hasParameter("operation:tolerance")) {
    setTolerance(Math.max(Math.min(getParameter("operation:tolerance"), properties.smoothingTolerance), 0));
  } else {
    setTolerance(0);
  }
  
  if (properties.useFeedQ &&
      hasParameter("operation-strategy") &&
      (getParameter("operation-strategy") != "drill")) {
    initializeActiveFeeds();
  } else {
    activeMovements = undefined;
  }
}

function onDwell(seconds) {
  validate(seconds >= 0);
  writeBlock("CYCL DEF 9.0 " + localize("DWELL TIME"));
  writeBlock("CYCL DEF 9.1 DWELL " + secFormat.format(seconds));
}

function onParameter(name, value) {
  if (name == "operation-comment") {
    writeStructureComment(value);
  } else if (name == "operation-structure-comment") {
    writeStructureComment("  " + value);
  }
}

function onDrilling(cycle) {
  writeBlock("L" + zOutput.format(cycle.clearance) + radiusCompensationTable.lookup(radiusCompensation) + " FMAX");

  writeBlock("CYCL DEF 1.0 PECKING");
  writeBlock("CYCL DEF 1.1 SET UP " + xyzFormat.format(cycle.clearance - cycle.stock));
  writeBlock("CYCL DEF 1.2 DEPTH " + xyzFormat.format(-cycle.depth));
  writeBlock("CYCL DEF 1.3 PECKG " + xyzFormat.format(cycle.depth));
  writeBlock("CYCL DEF 1.4 DWELL " + secFormat.format(cycle.dwell));
  writeBlock("CYCL DEF 1.5 F" + feedFormat.format(cycle.feedrate));
}

function onCounterBoring(cycle) {
  writeBlock("L" + zOutput.format(cycle.clearance) + radiusCompensationTable.lookup(radiusCompensation) + " FMAX");

  writeBlock("CYCL DEF 1.0 PECKING");
  writeBlock("CYCL DEF 1.1 SET UP " + xyzFormat.format(cycle.clearance - cycle.stock));
  writeBlock("CYCL DEF 1.2 DEPTH " + xyzFormat.format(-cycle.depth));
  writeBlock("CYCL DEF 1.3 PECKG " + xyzFormat.format(cycle.depth));
  writeBlock("CYCL DEF 1.4 DWELL " + secFormat.format(cycle.dwell));
  writeBlock("CYCL DEF 1.5 F" + feedFormat.format(cycle.feedrate));
}

function onChipBreaking(cycle) {
  writeBlock("L" + zOutput.format(cycle.clearance) + radiusCompensationTable.lookup(radiusCompensation) + " FMAX");

  writeBlock("CYCL DEF 1.0 PECKING");
  writeBlock("CYCL DEF 1.1 SET UP " + xyzFormat.format(cycle.clearance - cycle.stock));
  writeBlock("CYCL DEF 1.2 DEPTH " + xyzFormat.format(-cycle.depth));
  writeBlock("CYCL DEF 1.3 PECKG " + xyzFormat.format(cycle.incrementalDepth));
  writeBlock("CYCL DEF 1.4 DWELL " + secFormat.format(cycle.dwell));
  writeBlock("CYCL DEF 1.5 F" + feedFormat.format(cycle.feedrate));
}

function onDeepDrilling(cycle) {
  writeBlock("L" + zOutput.format(cycle.clearance) + radiusCompensationTable.lookup(radiusCompensation) + " FMAX");

  writeBlock("CYCL DEF 1.0 PECKING");
  writeBlock("CYCL DEF 1.1 SET UP " + xyzFormat.format(cycle.clearance - cycle.stock));
  writeBlock("CYCL DEF 1.2 DEPTH " + xyzFormat.format(-cycle.depth));
  writeBlock("CYCL DEF 1.3 PECKG " + xyzFormat.format(cycle.incrementalDepth));
  writeBlock("CYCL DEF 1.4 DWELL " + secFormat.format(cycle.dwell));
  writeBlock("CYCL DEF 1.5 F" + feedFormat.format(cycle.feedrate));
}

function onLeftTapping(cycle) {
  if (properties.rigidTapping) {
    writeBlock("L" + zOutput.format(cycle.clearance) + radiusCompensationTable.lookup(radiusCompensation) + " FMAX");
  
    writeBlock("CYCL DEF 17.0 TAPPING");
    writeBlock("CYCL DEF 17.1 SET UP " + xyzFormat.format(cycle.clearance - cycle.stock));
    writeBlock("CYCL DEF 17.2 DEPTH " + xyzFormat.format(-cycle.depth));
    writeBlock("CYCL DEF 17.3 PITCH " + pitchFormat.format(-tool.threadPitch));
  } else {
    expandCurrentCycle = properties.expandCycles;
    if (!expandCurrentCycle) {
      cycleNotSupported();
    }
  }
}

function onRightTapping(cycle) {
  if (properties.rigidTapping) {
    writeBlock("L" + zOutput.format(cycle.clearance) + radiusCompensationTable.lookup(radiusCompensation) + " FMAX");
    
    writeBlock("CYCL DEF 17.0 TAPPING");
    writeBlock("CYCL DEF 17.1 SET UP " + xyzFormat.format(cycle.clearance - cycle.stock));
    writeBlock("CYCL DEF 17.2 DEPTH " + xyzFormat.format(-cycle.depth));
    writeBlock("CYCL DEF 17.3 PITCH " + pitchFormat.format(tool.threadPitch));
  } else {
    writeBlock("L" + zOutput.format(cycle.clearance) + radiusCompensationTable.lookup(radiusCompensation) + " FMAX");

    writeBlock("CYCL DEF 2.0 TAPPING");
    writeBlock("CYCL DEF 2.1 SET UP " + xyzFormat.format(cycle.clearance - cycle.stock));
    writeBlock("CYCL DEF 2.2 DEPTH " + xyzFormat.format(-cycle.depth));
    writeBlock("CYCL DEF 2.3 DWELL 0");
    writeBlock("CYCL DEF 2.4 F" + feedFormat.format(tool.getTappingFeedrate()));
  }
}

function onCircularPocketMilling(cycle) {																								// CYCL circular pocket milling included 13.01.2011 awi
  if (tool.taperAngle > 0) {
    error(localize("Circular pocket milling is not supported for taper tools."));
    return;
  }
  
  writeBlock("L" + zOutput.format(cycle.clearance) + radiusCompensationTable.lookup(radiusCompensation) + " FMAX");

  writeBlock("CYCL DEF 5.0 CIRCULAR POCKET");
  writeBlock("CYCL DEF 5.1 SET UP " + xyzFormat.format(cycle.clearance));
  writeBlock("CYCL DEF 5.2 DEPTH " + xyzFormat.format(-cycle.depth));
  writeBlock("CYCL DEF 5.3 PECKG " + xyzFormat.format(cycle.stepover) +  " F" + feedFormat.format(cycle.feedrate/3));
  writeBlock("CYCL DEF 5.4 RADIUS " + xyzFormat.format(cycle.diameter/2));
  writeBlock("CYCL DEF 5.5 F" + feedFormat.format(cycle.feedrate) + " DR+");
}

/** Returns the best discrete disengagement direction for the specified direction. */
function getDisengagementDirection(direction) {
  switch (getQuadrant(direction + 45 * Math.PI/180)) {
  case 0:
    return 3;
  case 1:
    return 4;
  case 2:
    return 1;
  case 3:
    return 2;
  }
  error(localize("Invalid disengagement direction."));
  return 3;
}

var expandCurrentCycle = false;

function onCycle() {
  if (pendingRadiusCompensation >= 0) {
    error("Radius compensation cannot be activated/deactivated for a circular move.");
  }

  expandCurrentCycle = false;

  if (cycle.clearance != undefined) {
    if (getCurrentPosition().z < cycle.clearance) {
      writeBlock("L" + zOutput.format(cycle.clearance) + radiusCompensationTable.lookup(radiusCompensation) + " FMAX");
      setCurrentPositionZ(cycle.clearance);
    }
  }

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
      onLeftTapping(cycle);
    } else {
      onRightTapping(cycle);
    }
    break;
  case "left-tapping":
    onLeftTapping(cycle);
    break;
  case "right-tapping":
    onRightTapping(cycle);
    break;
/*
  case "reaming":
    onReaming(cycle);
    break;
  case "stop-boring":
    onStopBoring(cycle);
    break;
  case "fine-boring":
    onFineBoring(cycle);
    break;
  case "back-boring":
    onBackBoring(cycle);
    break;
  case "boring":
    onBoring(cycle);
    break;
*/
  case "circular-pocket-milling":
    onCircularPocketMilling(cycle);
    break;
  default:
    expandCurrentCycle = properties.expandCycles;
    if (!expandCurrentCycle) {
      cycleNotSupported();
    }
  }
}

function onCyclePoint(x, y, z) {
  if (!expandCurrentCycle) {
    // execute current cycle after this positioning block
    writeBlock("L" + xOutput.format(x) + yOutput.format(y) + " FMAX " + mFormat.format(99));
  } else {
    expandCyclePoint(x, y, z);
  }
}

function onCycleEnd() {
  zOutput.reset();
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

function onRapid(x, y, z) {
  var xyz = xOutput.format(x) + yOutput.format(y) + zOutput.format(z);
  if (xyz) {
    pendingRadiusCompensation = -1;
    writeBlock("L" + xyz + radiusCompensationTable.lookup(radiusCompensation) + " FMAX");
  }
  forceFeed();
}

function onLinear(x, y, z, feed) {
  var xyz = xOutput.format(x) + yOutput.format(y) + zOutput.format(z);
  var f = getFeed(feed);
  if (xyz) {
    pendingRadiusCompensation = -1;
    writeBlock("L" + xyz + radiusCompensationTable.lookup(radiusCompensation) + f);
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      forceFeed(); // force feed on next line
    } else {
      pendingRadiusCompensation = -1;
      writeBlock("L" + radiusCompensationTable.lookup(radiusCompensation) + f);
    }
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (pendingRadiusCompensation >= 0) {
    error("Radius compensation cannot be activated/deactivated for a circular move.");
  }

  switch (getCircularPlane()) {
  case PLANE_XY:
    writeBlock("CC X" + xyzFormat.format(cx) + " Y" + xyzFormat.format(cy));
    break;
  case PLANE_ZX:
    if (!isHelical()) {
      writeBlock("CC X" + xyzFormat.format(cx) + " Z" + xyzFormat.format(cz));
    }
    break;
  case PLANE_YZ:
    if (!isHelical()) {
      writeBlock("CC Y" + xyzFormat.format(cy) + " Z" + xyzFormat.format(cz));
    }
    break;
  default:
    var t = tolerance;
    if ((t == 0) && hasParameter("operation:tolerance")) {
      t = getParameter("operation:tolerance");
    }
    linearize(t);
    return;
  }

  if (isHelical()) {
    if (getCircularPlane() == PLANE_XY) {
      // IPA must have same sign as DR
      var sweep = (clockwise ? -1 : 1) * Math.abs(getCircularSweep());
      var block = "CP IPA" + paFormat.format(sweep) + zOutput.format(z);
      block += clockwise ? " DR-" : " DR+";
      block += /*radiusCompensationTable.lookup(radiusCompensation) +*/ getFeed(feed);
      writeBlock(block);
      invalidateXYZ();
//    } else if (getCircularPlane() == PLANE_ZX) {
//      // IPA must have same sign as DR
//      var sweep = (clockwise ? -1 : 1) * Math.abs(getCircularSweep());
//      var block = "CP IPA" + paFormat.format(sweep) + yOutput.format(z);
//      block += clockwise ? " DR-" : " DR+";
//      block += /*radiusCompensationTable.lookup(radiusCompensation) +*/ getFeed(feed);
//      writeBlock(block);
//      invalidateXYZ();
//    } else if (getCircularPlane() == PLANE_YZ) {
//      // IPA must have same sign as DR
//      var sweep = (clockwise ? -1 : 1) * Math.abs(getCircularSweep());
//      var block = "CP IPA" + paFormat.format(sweep) + xOutput.format(z);
//      block += clockwise ? " DR-" : " DR+";
//      block += /*radiusCompensationTable.lookup(radiusCompensation) +*/ getFeed(feed);
//      writeBlock(block);
//      invalidateXYZ();
    } else {
      var t = tolerance;
      if ((t == 0) && hasParameter("operation:tolerance")) {
        t = getParameter("operation:tolerance");
      }
      linearize(t);
    }
  } else {
    // IPA must have same sign as DR
    var sweep = (clockwise ? -1 : 1) * Math.abs(getCircularSweep());
    var block = "CP IPA" + paFormat.format(sweep);
    block += clockwise ? " DR-" : " DR+";
    block += /*radiusCompensationTable.lookup(radiusCompensation) +*/ getFeed(feed);
    writeBlock(block);
    invalidateXYZ();
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
  case COOLANT_MIST:
  case COOLANT_THROUGH_TOOL:
  case COOLANT_AIR:
  case COOLANT_AIR_THROUGH_TOOL:
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
  // COMMAND_START_SPINDLE
  COMMAND_STOP_SPINDLE:5
  //COMMAND_ORIENTATE_SPINDLE:19,
  //COMMAND_LOAD_TOOL:6, // do not use
  //COMMAND_COOLANT_ON,
  //COMMAND_COOLANT_OFF,
  //COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION
  //COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION
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
  case COMMAND_START_CHIP_TRANSPORT:
    return;
  case COMMAND_STOP_CHIP_TRANSPORT:
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
  invalidate();
}

function onClose() {
  setTolerance(0);
  setCoolant(COOLANT_OFF);
  if (getNumberOfSections() > 0) {
    onCommand(COMMAND_BREAK_CONTROL);
  }

  onCommand(COMMAND_STOP_SPINDLE);

  //writeBlock("CYCL DEF 7.0 " + localize("DATUM SHIFT"));
  //writeBlock("CYCL DEF 7.1 #" + 0);

  writeBlock("L Z" + xyzFormat.format(machineConfiguration.getRetractPlane()) + " R0 FMAX " + mFormat.format(properties.useM92 ? 92 : 91));

  var homeXY = "";
  if (machineConfiguration.hasHomePositionX()) {
    homeXY += " X" + xyzFormat.format(machineConfiguration.getHomePositionX());
  }
  if (machineConfiguration.hasHomePositionY()) {
    homeXY += " Y" + xyzFormat.format(machineConfiguration.getHomePositionY());
  }
  if (homeXY) {
    writeBlock("L" + homeXY + " R0 FMAX " + mFormat.format(properties.useM92 ? 92 : 91));
  }

  onCommand(COMMAND_STOP_CHIP_TRANSPORT);
  writeBlock(mFormat.format(30)); // stop program, spindle stop, coolant off

  writeBlock(
    "END PGM" + (programName ? (SP + programName) : "") + ((unit == MM) ? " MM" : " INCH")
  );
}
