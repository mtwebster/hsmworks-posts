/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Tool sheet CSV configuration.

  $Revision: 25499 $
  $Date: 2011-05-24 21:01:06 +0200 (ti, 24 maj 2011) $
  
  FORKID {BEBD3A50-28C9-4d8f-B6BE-9AE2EC3214D9}
*/

description = "Tool Sheet CSV";
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

function onSection() {
  skipRemainingSection();
}

function onClose() {
  feedFormat.setDecimalSymbol(properties.decimal);
  secFormat.setDecimalSymbol(properties.decimal);
  angleFormat.setDecimalSymbol(properties.decimal);
  pitchFormat.setDecimalSymbol(properties.decimal);
  spatialFormat.setDecimalSymbol(properties.decimal);

  var s = properties.separator;
  writeln(["TOOL #","DIAMETER #","LENGTH #","TYPE","COMMENT","DIAMETER","CORNER RADIUS","ANGLE","BODY LENGTH","FLUTE #","MAXIMUM FEED","MAXIMUM SPINDLE SPEED","FEED DISTANCE","RAPID DISTANCE","CYCLE TIME"].join(s));
  
  var tools = getToolTable();
  if (tools.getNumberOfTools() > 0) {
    for (var i = 0; i < tools.getNumberOfTools(); ++i) {
      var tool = tools.getTool(i);

      var record = "T" + toolFormat.format(tool.number);
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

      var maximumFeed = 0;
      var maximumSpindleSpeed = 0;
      var cuttingDistance = 0;
      var rapidDistance = 0;
      var cycleTime = 0;
      for (var j = 0; j < getNumberOfSections(); ++j) {
        var section = getSection(j);
        if (section.getTool().number == tool.number) {
          maximumFeed = Math.max(maximumFeed, section.getMaximumFeedrate());
          maximumSpindleSpeed = Math.max(maximumSpindleSpeed, section.getMaximumSpindleSpeed());
          cuttingDistance += section.getCuttingDistance();
          rapidDistance += section.getRapidDistance();
          cycleTime += section.getCycleTime();
        }
      }
      if (properties.rapidFeed > 0) {
        cycleTime += rapidDistance/properties.rapidFeed;
      }

      record += s + feedFormat.format(maximumFeed);
      record += s + maximumSpindleSpeed;
      record += s + spatialFormat.format(cuttingDistance);
      record += s + spatialFormat.format(rapidDistance);
      record += s + formatCycleTime(cycleTime);

      writeln(record);
    }
  }
}
