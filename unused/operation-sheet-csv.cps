/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Operation sheet CSV configuration.

  $Revision: 25499 $
  $Date: 2011-05-24 21:01:06 +0200 (ti, 24 maj 2011) $
  
  FORKID {FD67790C-7676-4ee2-B726-87942A6FAB34}
*/

description = "Operation Sheet CSV";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;

extension = "csv";
mimetype = "plain/csv";
setCodePage("ascii");

properties = {
  decimal: ".", // decimal symbol
  separator: ";", // field separator
  rapidFeed: 10000 // the rapid traversal feed
};

var feedFormat = createFormat({decimals:(unit == MM ? 0 : 2)});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3});
var angleFormat = createFormat({decimals:0, scale:DEG});
var pitchFormat = createFormat({decimals:3});
var spatialFormat = createFormat({decimals:3});
var taperFormat = angleFormat; // share format

function quote(text) {
  var result = "";
  for (var i = 0; i < text.length; ++i) {
    var ch = text.charAt(i);
    switch (ch) {
    case "\\":
    case "\"":
      result += "\\";
    }
    result += ch;
  }
  return "\"" + result + "\"";
}

function formatCycleTime(cycleTime) {
  cycleTime = cycleTime + 0.5; // round up
  var seconds = cycleTime % 60 | 0;
  var minutes = ((cycleTime - seconds)/60 | 0) % 60;
  var hours = (cycleTime - minutes * 60 - seconds)/(60 * 60) | 0;
  return subst("%1:%2:%3", hours, minutes, seconds);
}

function getStrategyDescription() {
  if (!hasParameter("operation-strategy")) {
    return "";
  }
  
  var strategies = {
    drill: localize("Drilling"),
    face: localize("Facing"),
    path3d: localize("3D Path"),
    pocket2d: localize("Pocket 2D"),
    contour2d: localize("Contour 2D"),
    adaptive2d: localize("Adaptive 2D"),
    
    contour_new: localize("Contour"),
    contour: localize("Contour"),
    parallel_new: localize("Parallel"),
    parallel: localize("Parallel"),
    pocket_new: localize("Pocket"),
    pocket: localize("Pocket"),
    adaptive: localize("Adaptive"),
    horizontal_new: localize("Horizontal"),
    horizontal: localize("Horizontal"),
    morph: localize("Morph"),
    pencil_new: localize("Pencil"),
    pencil: localize("Pencil"),
    project: localize("Project"),
    radial_new: localize("Radial"),
    radial: localize("Radial"),
    scallop_new: localize("Scallop"),
    scallop: localize("Scallop"),
    spiral_new: localize("Spiral"),
    spiral: localize("Spiral"),
    swarf: localize("Swarf"),
    multiAxisContour: localize("Multi-Axis Contour")
  };
  var description = "";
  if (strategies[getParameter("operation-strategy")]) {
    description = strategies[getParameter("operation-strategy")];
  } else {
    description = localize("Unspecified");
  }
  return description;
}

var cachedParameters = {};

function onParameter(name, value) {
  cachedParameters[name] = value;
}

function onOpen() {
  writeln(["OPERATION","COMMENT","STRATEGY","TOLERANCE","RADIAL STOCK TO LEAVE","AXIAL STOCK TO LEAVE","STEPDOWN","STEPOVER","TOOL #","DIAMETER #","LENGTH #","TYPE","COMMENT","DIAMETER","CORNER RADIUS","ANGLE","BODY LENGTH","FLUTE #","MAXIMUM FEED","MAXIMUM SPINDLE SPEED","FEED DISTANCE","RAPID DISTANCE","CYCLE TIME"].join(properties.separator));
  cachedParameters = {};
}

function onSection() {
  feedFormat.setDecimalSymbol(properties.decimal);
  secFormat.setDecimalSymbol(properties.decimal);
  angleFormat.setDecimalSymbol(properties.decimal);
  pitchFormat.setDecimalSymbol(properties.decimal);
  spatialFormat.setDecimalSymbol(properties.decimal);

  var s = properties.separator;

  var tolerance = cachedParameters["operation:tolerance"];
  var stockToLeave = cachedParameters["operation:stockToLeave"];
  var axialStockToLeave = cachedParameters["operation:verticalStockToLeave"];
  var maximumStepdown = cachedParameters["operation:maximumStepdown"];
  var maximumStepover = cachedParameters["operation:maximumStepover"] ? cachedParameters["operation:maximumStepover"] : cachedParameters["operation:stepover"];

  var record = "" + (getCurrentSectionId() + 1);
  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    record += s + quote(comment);
  } else {
    record += s;
  }
  record += s + quote(getStrategyDescription());
  record += s + (tolerance ? spatialFormat.format(tolerance) : "");
  record += s + (stockToLeave ? spatialFormat.format(stockToLeave) : "");
  record += s + (axialStockToLeave ? spatialFormat.format(axialStockToLeave) : "");
  record += s + (maximumStepdown ? spatialFormat.format(maximumStepdown) : "");
  record += s + (maximumStepover ? spatialFormat.format(maximumStepover) : "");

  record += s + "T" + toolFormat.format(tool.number);
  record += s + "D" + toolFormat.format(tool.diameterOffset);
  record += s + "L" + toolFormat.format(tool.lengthOffset);
  record += s + quote(getToolTypeName(tool.type));
  if (tool.comment) {
    record += s + quote(tool.comment);
  } else {
    record += s;
  }
  record += s + spatialFormat.format(tool.diameter);
  if (tool.cornerRadius) {
    record += s + spatialFormat.format(tool.cornerRadius);
  } else {
    record += s;
  }
  if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
    record += s + taperFormat.format(tool.taperAngle);
  } else {
    record += s;
  }
  record += s + spatialFormat.format(tool.bodyLength);
  record += s + spatialFormat.format(tool.numberOfFlutes);

  var maximumFeed = currentSection.getMaximumFeedrate();
  var maximumSpindleSpeed = currentSection.getMaximumSpindleSpeed();
  var cuttingDistance = currentSection.getCuttingDistance();
  var rapidDistance = currentSection.getRapidDistance();
  var cycleTime = currentSection.getCycleTime();
  if (properties.rapidFeed > 0) {
    cycleTime += rapidDistance/properties.rapidFeed;
  }

  record += s + feedFormat.format(maximumFeed);
  record += s + maximumSpindleSpeed;
  record += s + spatialFormat.format(cuttingDistance);
  record += s + spatialFormat.format(rapidDistance);
  record += s + formatCycleTime(cycleTime);
  writeln(record);

  skipRemainingSection();
}

function onSectionEnd() {
  cachedParameters = {};
}
