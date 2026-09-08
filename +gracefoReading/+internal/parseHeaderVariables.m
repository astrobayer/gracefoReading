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
%                One field per variable, named via
%                matlab.lang.makeValidName; each field is a struct of
%                the parsed attributes, scalar attributes as char and
%                list attributes as cellstr. Variables without
%                attributes get an empty struct.
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
%     - Field names are sanitized, so two variables whose names differ
%       only in characters that makeValidName removes would collide.
%
%   ERRORS
%     (none; an unparsable header simply yields no variables, which
%     readL1b then reports as gracefoReading:readL1b:noVariables)
%
%   EXAMPLE
%     % internal use only; called by parseYamlProduct:
%     [names, attrs] = gracefoReading.internal.parseHeaderVariables(hdr);
%
%   See also gracefoReading.readL1b, gracefoReading.internal.parseYamlProduct
%
%   Toolbox:  gracefoReading v1.0.1
%   Created:  2026-08-01
%   Updated:  2026-08-14
%   Author:   Developed by Matthias Weigelt with the help of Anthropic
%             Claude Opus 5, 2026-08-14

arguments
    headerLines (:,1) cell
end

varNames = {};
varAttrs = struct();
inVars = false;
current = '';
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
        current = strtrim(erase(tok{1}, {'''', '"'}));
        varNames{end+1} = current; %#ok<AGROW>
        varAttrs.(matlab.lang.makeValidName(current)) = struct();
        listAttr = '';
        continue
    end
    % real style: "    - varname:"
    tok = regexp(ln, '^\s{2,6}-\s+([A-Za-z_]\w*):\s*$', 'tokens', 'once');
    if ~isempty(tok)
        current = tok{1};
        varNames{end+1} = current; %#ok<AGROW>
        varAttrs.(matlab.lang.makeValidName(current)) = struct();
        listAttr = '';
        continue
    end
    % list-attribute item: deeply indented "- item"
    tok = regexp(ln, '^\s{8,}-\s+(.*\S)\s*$', 'tokens', 'once');
    if ~isempty(tok) && ~isempty(current) && ~isempty(listAttr)
        fn = matlab.lang.makeValidName(current);
        if ~isfield(varAttrs.(fn), listAttr)
            varAttrs.(fn).(listAttr) = {};
        end
        varAttrs.(fn).(listAttr){end+1} = strtrim(erase(tok{1}, {'''', '"'}));
        continue
    end
    % scalar attribute or start of list attribute: "        key: value"
    tok = regexp(ln, '^\s{6,}([A-Za-z_]\w*):\s*(.*)$', 'tokens', 'once');
    if ~isempty(tok) && ~isempty(current)
        key = matlab.lang.makeValidName(tok{1});
        val = strtrim(erase(tok{2}, {'''', '"'}));
        fn = matlab.lang.makeValidName(current);
        if isempty(val)
            listAttr = key;                      % list values follow
        else
            varAttrs.(fn).(key) = val;
            listAttr = '';
        end
        continue
    end
    % any other 2-space-indented key ends the variables block
    if ~isempty(regexp(ln, '^  \S', 'once'))
        inVars = false;
    end
end
end
