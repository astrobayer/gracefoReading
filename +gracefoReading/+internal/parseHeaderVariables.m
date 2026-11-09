function [varNames, varAttrs] = parseHeaderVariables(headerLines)
%PARSEHEADERVARIABLES  Parse variable declarations from an L1B YAML header.
%
%   SYNTAX
%     [varNames, varAttrs] = gracefoReading.internal.parseHeaderVariables(headerLines)
%
%   DESCRIPTION
%     Extracts the ordered list of data-column variables and their
%     attributes from the header of a GRACE-FO Level-1B ASCII file.
%     Two declaration styles are supported:
%       real RL04 files:  "  variables:"             with "    - varname:"
%       legacy/synthetic: "  variable_descriptions:" with "    - name: varname"
%     Attribute lines (units, long_name, comment, ...) are indented
%     deeper than the variable entry; list-valued attributes
%     (flag_meanings, value_meanings, flag_masks) collect the
%     subsequent "- item" lines. Internal function - the public
%     interface is gracefoReading.readL1b.
%
%   INPUT
%     headerLines - cellstr, [H x 1]
%                Raw header lines including the "# End of YAML header"
%                line.
%                Required, positional.
%
%   OUTPUT
%     varNames - cellstr, [1 x V]
%                Variable names in file column order.
%     varAttrs - struct, 1x1
%                One field per variable, named by
%                gracefoReading.internal.variableFieldNames - the one
%                rule every consumer of this struct uses; each field
%                is a struct of the parsed attributes, scalar
%                attributes as char and list attributes as cellstr.
%                Variables without attributes get an empty struct.
%                Index varNames and the field-name list positionally
%                rather than assuming name == field name.
%
%   ACCURACY AND LIMITATIONS
%     - This is a targeted parser for the header dialect of the L1B
%       products, not a general YAML implementation: anchors, flow
%       mappings, multi-line scalars and quoted keys are not handled.
%     - Variable order is the order of declaration, which the products
%       guarantee to match the column order; a file violating that
%       would be misread and is not detectable here.
%     - Attribute values are kept as text exactly as written, with no
%       type conversion; numeric attributes must be converted by the
%       caller.
%     - A variable name is whatever stands before the terminating
%       colon, so it need not be a MATLAB identifier: AHK1B declares
%       "TSU Z-", with a space, and the identifier-only pattern used
%       until 2026-09-22 dropped that column silently. A name
%       containing a colon is still not recognised.
%     - Field names are sanitized AND made unique across the whole
%       ordered list, so names differing only in characters
%       makeValidName maps together (AHK1B's "TSU Y+" / "TSU Y-")
%       stay distinct fields instead of overwriting each other. The
%       field name is then a per-file detail; match on varNames.
%
%   ERRORS
%     (none; an unparsable header simply yields no variables, which
%     readL1b then reports as gracefoReading:readL1b:noVariables)
%
%   EXAMPLE
%     % internal use only; called by parseYamlProduct:
%     [names, attrs] = gracefoReading.internal.parseHeaderVariables(hdr);
%
%   See also gracefoReading.readL1b,
%            gracefoReading.internal.parseYamlProduct,
%            gracefoReading.internal.variableFieldNames
%
%   Toolbox:  gracefoReading v1.3.3
%   Created:  2026-08-01
%   Updated:  2026-09-22
%   Author:   Matthias Weigelt with support of Anthropic Claude

arguments
    headerLines (:,1) cell
end

varNames = {};
attrCells = {};
inVars = false;
ci = 0;                                  % index of the variable being filled
listAttr = '';

for i = 1:numel(headerLines)
    ln = headerLines{i};
    if contains(ln, 'End of YAML header'), break; end

    if ~isempty(regexp(ln, '^  (variables|variable_descriptions):\s*$', 'once'))
        inVars = true;
        continue
    end
    if ~inVars, continue; end

    % legacy style: "    - name: varname"
    tok = regexp(ln, '^\s{2,6}-\s+name:\s*(\S+)\s*$', 'tokens', 'once');
    if ~isempty(tok)
        varNames{end+1} = strtrim(erase(tok{1}, {'''', '"'})); %#ok<AGROW>
        attrCells{end+1} = struct(); %#ok<AGROW>
        ci = numel(varNames);
        listAttr = '';
        continue
    end
    % real style: "    - varname:". The name is NOT required to be a
    % MATLAB identifier: AHK1B declares "TSU Z-" with a space, and the
    % identifier-only pattern used before dropped that column without a
    % word (V-13, issue #19). Anything up to the terminating colon is
    % taken as the name; a colon inside it would be ambiguous and is
    % excluded, which also keeps attribute lines out of this branch.
    tok = regexp(ln, '^\s{2,6}-\s+(\S[^:]*?)\s*:\s*$', 'tokens', 'once');
    if ~isempty(tok)
        varNames{end+1} = strtrim(erase(tok{1}, {'''', '"'})); %#ok<AGROW>
        attrCells{end+1} = struct(); %#ok<AGROW>
        ci = numel(varNames);
        listAttr = '';
        continue
    end
    % list-attribute item: deeply indented "- item"
    tok = regexp(ln, '^\s{8,}-\s+(.*\S)\s*$', 'tokens', 'once');
    if ~isempty(tok) && ci > 0 && ~isempty(listAttr)
        if ~isfield(attrCells{ci}, listAttr)
            attrCells{ci}.(listAttr) = {};
        end
        attrCells{ci}.(listAttr){end+1} = strtrim(erase(tok{1}, {'''', '"'}));
        continue
    end
    % scalar attribute or start of list attribute: "        key: value"
    tok = regexp(ln, '^\s{6,}([A-Za-z_]\w*):\s*(.*)$', 'tokens', 'once');
    if ~isempty(tok) && ci > 0
        key = matlab.lang.makeValidName(tok{1});
        val = strtrim(erase(tok{2}, {'''', '"'}));
        if isempty(val)
            listAttr = key;                      % list values follow
        else
            attrCells{ci}.(key) = val;
            listAttr = '';
        end
        continue
    end
    % any other 2-space-indented key ends the variables block
    if ~isempty(regexp(ln, '^  \S', 'once'))
        inVars = false;
    end
end

% Field names come from the ONE rule every consumer uses, applied to the
% complete ordered list: a per-name call cannot see a collision, and
% AHK1B's four sensor temperatures collide in pairs.
fieldNames = gracefoReading.internal.variableFieldNames(varNames);
varAttrs = struct();
for k = 1:numel(varNames)
    varAttrs.(fieldNames{k}) = attrCells{k};
end
end
