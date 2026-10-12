   function jqb --description 'Pretty-print JSON or JSONL through bat with JSON highlighting'
       jq '.' $argv | bat -l json
   end
