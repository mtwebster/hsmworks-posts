/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  SCM post processor configuration.

  $Revision: 25831 $
  $Date: 2011-06-20 02:01:39 +0200 (ma, 20 jun 2011) $
  
  FORKID {F4EC72B8-D7E7-45c4-A703-7089F83842E9}
*/

description = "Generic SCM-Prisma 110";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;

extension = "xxl";
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
  writeTools: true // writes the tools
};



var xyzFormat = createFormat({decimals:3});
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2)});
var toolFormat = createFormat({decimals:0});
var taperFormat = createFormat({decimals:1, scale:DEG});
var rpmFormat = createFormat({decimals:0});

var xOutput = createVariable({prefix:"X="}, xyzFormat);
var yOutput = createVariable({prefix:"Y="}, xyzFormat);
var zOutput = createVariable({prefix:"Z="}, xyzFormat);

var feedOutput = createVariable({prefix:"V="}, feedFormat);

// circular output
var iOutput = createVariable({prefix:"I=", force:true}, xyzFormat);
var jOutput = createVariable({prefix:"J=", force:true}, xyzFormat);

/**
  Writes the specified block.
*/
function writeBlock() {
  writeWords(arguments);
}

/**
  Output a comment.
*/
function writeComment(text) {
  if (text) {
    writeln("; " + text);
  }
}

function onOpen() {
  var workpiece = getWorkpiece();
  writeBlock("H", "DX=" + xyzFormat.format(workpiece.upper.x), "DY=" + xyzFormat.format(workpiece.upper.y), "DZ=" + xyzFormat.format(workpiece.upper.z), "-A", "*MM", "/DEF");
  writeComment(programName);
  if (programComment != programName) {
    writeComment(programComment);
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
  var abc = currentSection.workPlane.getTurnAndTilt(0, 2);
  writeBlock(
    "XPL",
    "X=" + xyzFormat.format(currentSection.workOrigin.x),
    "Y=" + xyzFormat.format(currentSection.workOrigin.y),
    "Z=" + xyzFormat.format(currentSection.workOrigin.z),
    "Q=" + abcFormat.format(abc.z),
    "R=" + abcFormat.format(abc.x)
  );
 
  forceAny();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  
  writeBlock(
    "XG0",
    xOutput.format(initialPosition.x),
    yOutput.format(initialPosition.y),
    zOutput.format(initialPosition.z),
    "T=" + toolFormat.format(tool.number),
    "S=" + rpmFormat.format(tool.spindleRPM)
  );
  feedOutput.reset();
}

function onRadiusCompensation() {
  if (radiusCompensation != RADIUS_COMPENSATION_OFF) {
    error(localize("Radius compensation mode not supported."));
  }
}

function onRapid(x, y, z) {
  writeBlock(
    "XG0",
    xOutput.format(x),
    yOutput.format(y),
    zOutput.format(z),
    "T=" + toolFormat.format(tool.number),
    "S=" + rpmFormat.format(tool.spindleRPM)
  );
  feedOutput.reset();
}

function onLinear(x, y, z, feed) {
  writeBlock("XL2P", xOutput.format(x), yOutput.format(y), zOutput.format(z), feedOutput.format(feed));
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (isHelical() || (getCircularPlane() != PLANE_XY)) {
    var t = tolerance;
    if ((t == 0) && hasParameter("operation:tolerance")) {
      t = getParameter("operation:tolerance");
    }
    linearize(t);
    return;
  }

  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
  writeBlock("XA2P", "G=" + (clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx), jOutput.format(cy), feedOutput.format(feed));
} 

function onSectionEnd() {
  writeBlock("XPL", "X=" + xyzFormat.format(0), "Y=" + xyzFormat.format(0), "Z=" + xyzFormat.format(0), "Q=" + abcFormat.format(0), "R=" + abcFormat.format(0)); // reset plane
  writeComment("******************************");
  
  forceAny();
}

function onClose() {
  // home position
  writeBlock("N", "X=" + xyzFormat.format(0), "Y=" + xyzFormat.format(0), "Z=" + xyzFormat.format(0), "; " + localize("home"));
}
