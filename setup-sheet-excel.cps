/**
  Copyright (C) 2007-2011 by HSMWorks ApS
  All rights reserved.

  Excel setup sheet configuration.

  $Revision: 25677 $
  $Date: 2011-06-06 17:42:15 +0200 (ma, 06 jun 2011) $
  
  FORKID {F4FA39E1-B6CA-4fbe-A094-8761870B1F78}
*/

description = "Setup Sheet Excel";
vendor = "HSMWorks ApS";
vendorUrl = "http://www.hsmworks.com";
legal = "Copyright (C) 2007-2011 HSMWorks ApS";
certificationLevel = 2;

extension = "xls";
mimetype = "text/xml";
keywords = "MODEL_IMAGE";
setCodePage("utf-8");

properties = {
  rapidFeed: 200, // the rapid traversal feed
  toolChangeTime: 15, // the time in seconds for a tool change
  listVariables: false // outputs the available variables to the log
};

var timeFormat = createFormat({width:2, zeropad:true, decimals:0});

/** Sets variable prefix. */
function prepend(prefix, variables) {
  var result = {};
  var p = prefix + ".";
  for (var k in variables) {
    result[p + k] = variables[k];
  }
  return result;
}

/** Returns the global program information. */
function getProgramInfo() {
  var result = {};
  result["name"] = (programName == undefined) ? "" : programName;
  result["comment"] = (programComment == undefined) ? "" : programComment;

  // 2003-06-11T00:00:00.000
  var now = new Date();
  result["generationTime"] = subst(
    "%1-%2-%3T%4:%5:%6.000",
    now.getFullYear(),
    timeFormat.format(now.getMonth() + 1),
    timeFormat.format(now.getDate()),
    timeFormat.format(now.getHours()),
    timeFormat.format(now.getMinutes()),
    timeFormat.format(now.getSeconds())
  );
  
  result["numberOfSections"] = getNumberOfSections();
  var tools = getToolTable();
  result["numberOfTools"] = tools.getNumberOfTools();

  var maximumFeed = 0;
  var maximumSpindleSpeed = 0;
  var cuttingDistance = 0;
  var rapidDistance = 0;
  var cycleTime = 0;

  var multipleWorkOffsets = false;
  var workOffset;
  var numberOfSections = getNumberOfSections();
  var currentTool;
  for (var i = 0; i < numberOfSections; ++i) {
    var section = getSection(i);

    if (workOffset == undefined) {
      workOffset = section.workOffset;
    } else {
      if (workOffset != section.workOffset) {
        multipleWorkOffsets = true;
      }
    }
    
    maximumFeed = Math.max(maximumFeed, section.getMaximumFeedrate());
    maximumSpindleSpeed = Math.max(maximumSpindleSpeed, section.getMaximumSpindleSpeed());
    cuttingDistance += section.getCuttingDistance();
    rapidDistance += section.getRapidDistance();
    cycleTime += section.getCycleTime();
    if (properties.rapidFeed > 0) {
      cycleTime += rapidDistance/properties.rapidFeed;
    }
    if (properties.toolChangeTime > 0) {
      var tool = section.getTool();
      if (currentTool != tool.number) {
        currentTool = tool.number;
        cycleTime += properties.toolChangeTime;
      }
    }
  }

  result["workOffset"] = multipleWorkOffsets ? "" : workOffset;
  result["maximumFeed"] = maximumFeed;
  result["maximumSpindleSpeed"] = maximumSpindleSpeed;
  result["cuttingDistance"] = cuttingDistance;
  result["rapidDistance"] = rapidDistance;
  result["cycleTime"] = formatTime(cycleTime);

  return prepend("program", result);
}

/** Returns the tool information in an array. */
function getToolInfo() {
  var result = [];
  var tools = getToolTable();
  for (var i = 0; i < tools.getNumberOfTools(); ++i) {
    var tool = tools.getTool(i);
    
    var maximumFeed = 0;
    var maximumSpindleSpeed = 0;
    var cuttingDistance = 0;
    var rapidDistance = 0;
    var cycleTime = 0;

    var numberOfSections = getNumberOfSections();
    for (var j = 0; j < numberOfSections; ++j) {
      var section = getSection(j);
      if (section.getTool().number != tool.number) {
        continue;
      }
   
      maximumFeed = Math.max(maximumFeed, section.getMaximumFeedrate());
      maximumSpindleSpeed = Math.max(maximumSpindleSpeed, section.getMaximumSpindleSpeed());
      cuttingDistance += section.getCuttingDistance();
      rapidDistance += section.getRapidDistance();
      cycleTime += section.getCycleTime();
      if (properties.rapidFeed > 0) {
        cycleTime += rapidDistance/properties.rapidFeed;
      }
    }

    var record = {
      "number": tool.number,
      "diameterOffset": tool.diameterOffset,
      "lengthOffset": tool.lengthOffset,
      "diameter": tool.diameter,
      "cornerRadius": tool.cornerRadius,
      "taperAngle": toDeg(tool.taperAngle),
      "fluteLength": tool.fluteLength,
      "shoulderLength": tool.shoulderLength,
      "bodyLength": tool.bodyLength,
      "numberOfFlutes": tool.numberOfFlutes,
      "type": getToolTypeName(tool.type),
      "holder": 0, // TAG: add support
      "comment": tool.comment,
      "maximumFeed": maximumFeed,
      "maximumSpindleSpeed": maximumSpindleSpeed,
      "cuttingDistance": cuttingDistance,
      "rapidDistance": rapidDistance,
      "cycleTime": formatTime(cycleTime)
    };

    result.push(prepend("tool", record));
  }
  return result;
}

var programInfo = {};
var operationInfo = [];
var toolInfo = [];
var global = (function(){return this;}).call();

function getVariable(variables, id) {
  // log("LOOKUP: " + id  + "=" + variables[id]);
  var value = variables[id];
  if (value != undefined) {
    var i = id.indexOf("(");
    if ((i >= 0) && (id.indexOf(")", i + 1) > i)) { // assume function
      try {
        value = eval.call(global, id); // TAG: not supported
      } catch(e) {
        value = undefined;
      }
    }
  }
  if (value != undefined) {
    return value;
  }
  warning(subst(localize("The variable '%1' is unknown."), id));
  if (false) {
    variables[id] = "$" + id; // avoid future warnings
    return "$" + id;
  }
  variables[id] = ""; // avoid future warnings
  return "";
}

function replaceVariables(variables, xml) {
  var ss = new Namespace("urn:schemas-microsoft-com:office:spreadsheet");
  var datas = xml..ss::Data;
  for (var i = 0; i < datas.length(); ++i) {
    var e = datas[i];
    var t = e.valueOf();
    if (/*(t.length() > 1) &&*/ (t.charAt(0) == "$")) { // variable
      var value = getVariable(variables, t.substr(1));
      switch (typeof(value)) {
      case "boolean":
        e.@ss::Type = "Boolean";
        value = value ? 1 : 0;
        break;
      case "number":
        e.@ss::Type = "Number"; // always using decimal .
        break;
      case "string":
      default:
        if ((value.indexOf("$") < 0) && (t.substr(t.length - 4) == "Time")) {
          e.@ss::Type = "DateTime";
        } else {
          e.@ss::Type = "String";
        }
      }
      datas[i] = value;
    }
  }
}

function updateWorksheet(worksheet) {
  default xml namespace = "urn:schemas-microsoft-com:office:spreadsheet";
  var ss = new Namespace("urn:schemas-microsoft-com:office:spreadsheet");

  worksheet.@ss::Name = localize(worksheet.@ss::Name); // title

  // find operation rows to fill
  var datas = worksheet..ss::Row.ss::Cell.ss::Data.(function::valueOf() == "$OPERATION_ROW");
  for (var i = 0; i < datas.length(); ++i) {
    var row = datas[i].parent().parent();
    var table = row.parent();
    delete row.ss::Cell.ss::Data.(function::valueOf() == "$OPERATION_ROW")[0];

    for (var j = operationInfo.length - 1; j >= 0; --j) {
      var filledRow = row.copy();
      replaceVariables(operationInfo[j], filledRow); // TAG: include global info also
      table.insertChildAfter(row, filledRow);
    }

    var offset = getNumberOfSections() - 1;
    var base = row.childIndex();

    var rows = table.ss::Row;
    for (var r = 0; r < rows.length(); ++r) {
      var rr = rows[r];
      var index = parseInt(rr.@ss::Index);
      if ((index >= 0) && (rr.childIndex() > (base + offset))) {
        rr.@ss::Index = index + offset;
      }
    }

    delete table.children()[base];
    table.@ss::ExpandedRowCount = parseInt(table.@ss::ExpandedRowCount) + offset;
  }
 
  // find tool rows to fill
  var datas = worksheet..ss::Row.ss::Cell.ss::Data.(function::valueOf() == "$TOOL_ROW");
  for (var i = 0; i < datas.length(); ++i) {
    var row = datas[i].parent().parent();
    var table = row.parent();
    delete row.ss::Cell.ss::Data.(function::valueOf() == "$TOOL_ROW")[0];

    for (var j = toolInfo.length - 1; j >= 0; --j) {
      var filledRow = row.copy();
      replaceVariables(toolInfo[j], filledRow); // TAG: include global info also
      table.insertChildAfter(row, filledRow);
    }

    var offset = getNumberOfSections() - 1;
    var base = row.childIndex();

    var rows = table.ss::Row;
    for (var r = 0; r < rows.length(); ++r) {
      var rr = rows[r];
      var index = parseInt(rr.@ss::Index);
      if ((index >= 0) && (rr.childIndex() > (base + offset))) {
        rr.@ss::Index = index + offset;
      }
    }

    delete table.children()[base];
    table.@ss::ExpandedRowCount = parseInt(table.@ss::ExpandedRowCount) + offset;
  }

  replaceVariables(programInfo, worksheet);

  var datas = worksheet..ss::Data.(@ss::Type == "String");
  for (var i = 0; i < datas.length(); ++i) {
    var e = datas[i];
    var texts = e.text();
    for (var j = 0; j < texts.length(); ++j) {
      var t = texts[j];
      texts[j] = localize(t); // only allowed for strings
    }
  }
}

var cachedParameters = {};

function onParameter(name, value) {
  cachedParameters[name] = value;
}

function onOpen() {
  programInfo = getProgramInfo();

  programInfo["program.jobDescription"] = hasGlobalParameter("job-description") ? getGlobalParameter("job-description") : "";
  programInfo["program.partPath"] = hasGlobalParameter("document-path") ? getGlobalParameter("document-path") : "";
  programInfo["program.partName"] = FileSystem.getFilename(programInfo["program.partPath"]);
  programInfo["program.user"] = hasGlobalParameter("username") ? getGlobalParameter("username") : "";
  
  var workpiece = getWorkpiece();
  var delta = Vector.diff(workpiece.upper, workpiece.lower);
  programInfo["program.stockLowerX"] = workpiece.lower.x;
  programInfo["program.stockLowerY"] = workpiece.lower.y;
  programInfo["program.stockLowerZ"] = workpiece.lower.z;
  programInfo["program.stockUpperX"] = workpiece.upper.x;
  programInfo["program.stockUpperY"] = workpiece.upper.y;
  programInfo["program.stockUpperZ"] = workpiece.upper.z;
  programInfo["program.stockDX"] = delta.x;
  programInfo["program.stockDY"] = delta.y;
  programInfo["program.stockDZ"] = delta.z;

  var partLowerX = hasGlobalParameter("part-lower-x") ? getGlobalParameter("part-lower-x") : 0;
  var partLowerY = hasGlobalParameter("part-lower-y") ? getGlobalParameter("part-lower-y") : 0;
  var partLowerZ = hasGlobalParameter("part-lower-z") ? getGlobalParameter("part-lower-z") : 0;
  var partUpperX = hasGlobalParameter("part-upper-x") ? getGlobalParameter("part-upper-x") : 0;
  var partUpperY = hasGlobalParameter("part-upper-y") ? getGlobalParameter("part-upper-y") : 0;
  var partUpperZ = hasGlobalParameter("part-upper-z") ? getGlobalParameter("part-upper-z") : 0;

  programInfo["program.partLowerX"] = partLowerX;
  programInfo["program.partLowerY"] = partLowerY;
  programInfo["program.partLowerZ"] = partLowerZ;
  programInfo["program.partUpperX"] = partUpperX;
  programInfo["program.partUpperY"] = partUpperY;
  programInfo["program.partUpperZ"] = partUpperZ;
  programInfo["program.partDX"] = partUpperX - partLowerX;
  programInfo["program.partDY"] = partUpperY - partLowerY;
  programInfo["program.partDZ"] = partUpperZ - partLowerZ;
  
  toolInfo = getToolInfo();
  
  cachedParameters = {};
}

function onSection() {
  skipRemainingSection();
}

function getStrategy() {
  if (hasParameter("operation-strategy")) {
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
      swarf: localize("Multi-Axis Swarf"),
      multiAxisContour: localize("Multi-Axis Contour")
    };
    if (strategies[getParameter("operation-strategy")]) {
      return strategies[getParameter("operation-strategy")];
    }
  }
  return "";
}

/**
  Returns the specified coolant as a string.
*/
function getCoolantName(coolant) {
  switch (coolant) {
  case COOLANT_OFF:
    return localize("Off");
  case COOLANT_FLOOD:
    return localize("Flood");
  case COOLANT_MIST:
    return localize("Mist");
  case COOLANT_THROUGH_TOOL:
    return localize("Through tool");
  case COOLANT_AIR:
    return localize("Air");
  case COOLANT_AIR_THROUGH_TOOL:
    return localize("Air through tool");
  case COOLANT_SUCTION:
    return localize("Suction");
  case COOLANT_FLOOD_MIST:
    return localize("Flood and mist");
  case COOLANT_FLOOD_THROUGH_TOOL:
    return localize("Flood and through tool");
  default:
    return localize("Unknown");
  }
}

function onSectionEnd() {
  var operationParameters = {};
  
  operationParameters["id"] = currentSection.getId() + 1;
  operationParameters["description"] = hasParameter("operation-comment") ? getParameter("operation-comment") : "";
  operationParameters["strategy"] = getStrategy();
  operationParameters["workOffset"] = currentSection.workOffset;

  var tolerance = cachedParameters["operation:tolerance"];
  var stockToLeave = cachedParameters["operation:stockToLeave"];
  var axialStockToLeave = cachedParameters["operation:verticalStockToLeave"];
  var maximumStepdown = cachedParameters["operation:maximumStepdown"];
  var maximumStepover = cachedParameters["operation:maximumStepover"] ? cachedParameters["operation:maximumStepover"] : cachedParameters["operation:stepover"];
  var zRange = currentSection.getGlobalZRange();

  operationParameters["tolerance"] = tolerance;
  operationParameters["stockToLeave"] = stockToLeave;
  operationParameters["axialStockToLeave"] = axialStockToLeave;
  operationParameters["maximumStepdown"] = maximumStepdown;
  operationParameters["maximumStepover"] = maximumStepover;
  operationParameters["zdepth"] = zRange.getMinimum();
  var cycleTime = currentSection.getCycleTime();

  operationParameters["maximumFeed"] = currentSection.getMaximumFeedrate();
  operationParameters["maximumSpindleSpeed"] = currentSection.getMaximumSpindleSpeed();
  operationParameters["cuttingDistance"] = currentSection.getCuttingDistance();
  operationParameters["rapidDistance"] = currentSection.getRapidDistance();
  if (properties.rapidFeed > 0) {
    cycleTime += currentSection.getRapidDistance()/properties.rapidFeed;
  }
  operationParameters["cycleTime"] = formatTime(cycleTime);

  var tool = currentSection.getTool();
  operationParameters["tool.number"] = tool.number;
  operationParameters["tool.diameterOffset"] = tool.diameterOffset;
  operationParameters["tool.lengthOffset"] = tool.lengthOffset;
  operationParameters["tool.diameter"] = tool.diameter;
  operationParameters["tool.cornerRadius"] = tool.cornerRadius;
  operationParameters["tool.taperAngle"] = toDeg(tool.taperAngle);
  operationParameters["tool.fluteLength"] = tool.fluteLength;
  operationParameters["tool.shoulderLength"] = tool.shoulderLength;
  operationParameters["tool.bodyLength"] = tool.bodyLength;
  operationParameters["tool.numberOfFlutes"] = tool.numberOfFlutes;
  operationParameters["tool.type"] = getToolTypeName(tool.type);
  operationParameters["tool.spindleSpeed"] = tool.spindleSpeed;
  operationParameters["tool.coolant"] = getCoolantName(tool.coolant);
  operationParameters["tool.comment"] = tool.comment;

  operationInfo.push(prepend("operation", operationParameters));

  cachedParameters = {};
}

function formatTime(cycleTime) {
  cycleTime = cycleTime + 0.5; // round up
  var d = new Date(1899, 11, 31, 0, 0, cycleTime, 0);
  return subst(
    "%1-%2-%3T%4:%5:%6.000",
    d.getFullYear(),
    timeFormat.format(d.getMonth() + 1),
    timeFormat.format(d.getDate()),
    timeFormat.format(d.getHours()),
    timeFormat.format(d.getMinutes()),
    timeFormat.format(d.getSeconds())
  );
}

function dumpIds() {
  for (var k in programInfo) {
    log(k + " = " + programInfo[k]);
  }
  
  if (toolInfo.length > 0) {
    var variables = toolInfo[0];
    for (var k in variables) {
      log(k + " = " + variables[k]);
    }
  }

  if (operationInfo.length > 0) {
    var variables = operationInfo[0];
    for (var k in variables) {
      log(k + " = " + variables[k]);
    }
  }
}

function onClose() {
  if (properties.listVariables) {
    dumpIds();
  }
  
  var xml = loadText("setup-sheet-excel-template.xls", "utf-8");
  var xml = xml.replace(/<\?xml (.*?)\?>/, "");
  var d = new XML(xml);
  
  default xml namespace = "urn:schemas-microsoft-com:office:spreadsheet";
  var ss = new Namespace("urn:schemas-microsoft-com:office:spreadsheet");
  
  var worksheets = d.ss::Worksheet;
  for (var w in worksheets) {
    updateWorksheet(worksheets[w]);
  }

  writeln("<?xml version='1.0'?>");
  write(d.toXMLString());
}

function onTerminate() {
  //openUrl(getOutputPath());
  executeNoWait("excel", "\"" + getOutputPath() + "\"", false, "");
}
