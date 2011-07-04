/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  MultiCam ISO post processor configuration.

  $Revision: 25831 $
  $Date: 2011-06-20 02:01:39 +0200 (ma, 20 jun 2011) $
  
  FORKID {07A5CBE6-B093-419b-8CAB-3EF48FF73927}
*/

description = "MultiCam HPGL";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;
minimumRevision = 18094;

extension = "plt";
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
  separateWordsWithSpace: true, // specifies that the words should be separated with a white space
  rapidFeed: (63.5 * 60), // specifies the rapid traversal feed
  safeZ: 10 // specifies the safety distance above the stock
};

var numberOfToolSlots = 9999;

var WARNING_WORK_OFFSET = 0;
var WARNING_COOLANT = 1;



var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});
var hFormat = createFormat({prefix:"H", decimals:0});
var dFormat = createFormat({prefix:"D", decimals:0});

/** Returns the spatial value in HPGL unit. */
function toHPGL(value) {
  // 1 inch = 1016 HPGL;
  return value * 40;
}

var xyzFormat = createFormat({decimals:0, scale:40});
var zFormat = createFormat({decimals:0, scale:-40});
var angleFormat = createFormat({decimals:3, scale:DEG});
var feedFormat = createFormat({decimals:0});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3, forceDecimal:true}); // seconds - range 0.001-1000
var taperFormat = createFormat({decimals:1, scale:DEG});

var xOutput = createVariable({force:true}, xyzFormat);
var yOutput = createVariable({force:true}, xyzFormat);
var zOutput = createVariable({force:true}, zFormat);
var feedOutput = createVariable({}, feedFormat);

// collected state

/**
  Output a comment.
*/
function writeComment(text) {
  // not supported
}

function onOpen() {
  if (!properties.separateWordsWithSpace) {
    setWordSeparator("");
  }

  writeln(";IN;");
  writeln("ZZ1;"); // 3D mode
  writeln("PA;"); // absolute coordinate mode

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
          comment += " - " + localize("ZMIN") + "=" + zFormat.format(zRanges[tool.number].getMinimum());
        }
        comment += " - " + getToolTypeName(tool.type);
        writeComment(comment);
      }
    }
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

/** Force output of X, Y, Z, and F on next output. */
function forceAny() {
  forceXYZ();
  feedOutput.reset();
}

function onSection() {
  setTranslation(currentSection.workOrigin);
  setRotation(currentSection.workPlane);
  
  var insertToolCall = isFirstSection() || (tool.number != getPreviousSection().getTool().number);
  
  var retracted = false; // specifies that the tool has been retracted to the safe plane
  if (isFirstSection() || insertToolCall) {
    // retract to safe plane
    retracted = true;
    writeln("PU;"); // retract
    zOutput.reset();
  }
  
  if (insertToolCall) {
    retracted = true;
    onCommand(COMMAND_COOLANT_OFF);
  
    if (tool.number > numberOfToolSlots) {
      warning(localize("Tool number exceeds maximum value."));
    }

    writeln("SP" + toolFormat.format(tool.number) + ";");
    // TAG: add support writeln("TCInsert tool " + toolFormat.format(tool.number) + ";");
    
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
    writeln("ZO100," + rpmFormat.format(tool.spindleRPM) + ";");
    if (!tool.clockwise) {
      error(localize("Spindle direction not supported."));
      return;
    }
  }

  // wcs
  if (currentSection.workOffset != 0) {
    warningOnce(localize("Work offset is not supported."), WARNING_WORK_OFFSET);
  }

  forceXYZ();

  if (tool.coolant != COOLANT_OFF) {
    warningOnce(localize("Coolant not supported."), WARNING_COOLANT);
  }

  forceAny();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (!retracted) {
    if (getCurrentPosition().z < initialPosition.z) {
      //writeln("ZD" + zOutput.format(initialPosition.z) + ";");
      writeln("PD" + xOutput.format(getCurrentPosition().x) + "," + yOutput.format(getCurrentPosition().y) + "," + zOutput.format(initialPosition.z) + ";");
      //setCurrentPositionZ(initialPosition.z);
    }
  }

  if (insertToolCall) {
    writeln("PD" + xOutput.format(initialPosition.x) + "," + yOutput.format(initialPosition.y) + "," + zOutput.format(properties.safeZ) + ";");
    writeln("PD" + xOutput.format(initialPosition.x) + "," + yOutput.format(initialPosition.y) + "," + zOutput.format(initialPosition.z) + ";");
    //writeln("ZD" + zOutput.format(initialPosition.z) + ";");
  }
}

function onRadiusCompensation() {
  if (radiusCompensation != RADIUS_COMPENSATION_OFF) {
    error(localize("Radius compensation mode not supported."));
  }
}

function onRapid(_x, _y, _z) {
  var f = feedOutput.format(properties.rapidFeed/60.0);
  if (f) {
    writeln("SF" + f + ";");
  }
  
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  writeln("PD" + x + "," + y + "," + z + ";");
  feedOutput.reset();
}

function onLinear(_x, _y, _z, feed) {
  var f = feedOutput.format(feed/60.0);
  if (f) {
    writeln("SF" + f + ";");
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  writeln("PD" + x + "," + y + "," + z + ";");
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  var f = feedOutput.format(feed/60.0);
  if (f) {
    writeln("SF" + f + ";");
  }

  if (isHelical() || (getCircularPlane() != PLANE_XY)) {
    var t = tolerance;
    if (hasParameter("operation:tolerance")) {
      t = getParameter("operation:tolerance");
    }
    linearize(t);
    return;
  }
  writeln("AA" + xOutput.format(cx) + "," + yOutput.format(cy) + "," + angleFormat.format((clockwise ? -1 : 1) * getCircularSweep()) + ";");
}

function onCommand(command) {
  if (command != COMMAND_COOLANT_OFF) {
    error(localize("Unsupported command"));
  }
}

function onSectionEnd() {
  forceAny();
}

function onClose() {
  onCommand(COMMAND_COOLANT_OFF);

  writeln("PU;"); // retract
  zOutput.reset();

  if (!machineConfiguration.hasHomePositionX() && !machineConfiguration.hasHomePositionY()) {
    // writeln("PD" + xyzFormat.format(0) + "," + xyzFormat.format(0) + ";");
  } else {
    var homeX;
    if (machineConfiguration.hasHomePositionX()) {
      homeX = "X" + xyzFormat.format(machineConfiguration.getHomePositionX());
    }
    var homeY;
    if (machineConfiguration.hasHomePositionY()) {
      homeY = "Y" + xyzFormat.format(machineConfiguration.getHomePositionY());
    }
    writeln("PD" + homeX + "," + homeY + ";");
  }

  onImpliedCommand(COMMAND_STOP_SPINDLE);
  writeln("SP0;"); // spindle stop
}
