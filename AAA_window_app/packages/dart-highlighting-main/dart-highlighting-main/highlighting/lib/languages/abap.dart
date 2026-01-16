import 'package:highlighting/highlighting.dart';
import '../src/language_definition_common.dart';

final abap = Language(
  id: 'abap',
  name: 'ABAP',
  keywords: {
    'keyword': [
      'ADD', 'ASSERT', 'ASSIGN', 'BACK', 'BEGIN', 'BY', 'CALL', 'CASE', 'CATCH',
      'CHECK', 'CLASS', 'CLEAR', 'CLOSE', 'COMMIT', 'COMPUTE', 'CONCATENATE',
      'CONDENSE', 'CONSTANTS', 'CONTINUE', 'CONTROLS', 'CONVERT', 'CREATE',
      'DATA', 'DEFINE', 'DELETE', 'DESCRIBE', 'DIVIDE', 'DO', 'ELSE', 'ENDIF',
      'ENDCASE', 'ENDCLASS', 'ENDDO', 'ENDFORM', 'ENDFUNCTION', 'ENDLOOP',
      'ENDMETHOD', 'ENDMODULE', 'ENDON', 'ENDSELECT', 'ENDTRY', 'ENDWHILE',
      'EVENT', 'EXIT', 'FETCH', 'FORM', 'FORMAT', 'FREE', 'FROM', 'FUNCTION',
      'GENERATE', 'GET', 'GLOBAL', 'IF', 'IMPORT', 'INDEX', 'INTERFACE',
      'LEAVE', 'LIKE', 'LINE', 'LOAD', 'LOCAL', 'LOOP', 'MESSAGE', 'METHOD',
      'MODIFY', 'MODULE', 'MOVE', 'MULTIPLY', 'NEW-LINE', 'NEW-PAGE', 'OBJECTS',
      'OF', 'OFF', 'ON', 'OPEN', 'OTHERS', 'PACK', 'PARAMETER', 'PERFORM',
      'POSITION', 'PROGRAM', 'PUT', 'RAISE', 'READ', 'RECEIVE', 'REDUCE',
      'REFRESH', 'REJECT', 'REPORT', 'RESERVE', 'RESET', 'RETURN', 'ROLLBACK',
      'SCAN', 'SCROLL', 'SEARCH', 'SELECT', 'SET', 'SHIFT', 'SKIP', 'SORT',
      'SPLIT', 'STATICS', 'STOP', 'SUBMIT', 'SUBTRACT', 'SUM', 'SUPPRESS',
      'TABLES',
      'TRANSFER', 'TRANSLATE', 'TRY', 'TCODE', 'TYPES', 'UNPACK', 'UPDATE',
      'USING',
      'WHEN', 'WHILE', 'WINDOW', 'WRITE', 'EXPORTING', 'IMPORTING', 'NEW',
      'DESCENDING', 'IMPLEMENTATION', 'METHODS', 'DEFINITION', 'PUBLIC',
      'SECTION', 'DECIMALS', 'TO', 'END', 'PRIVATE', 'INTERFACES',
      'ENDINTERFACE', 'START', 'SELECTION', 'INITIALIZATION',
      'CHANGING', 'TABLE', 'IS', 'NOT', 'NULL', 'INSERT', 'VALUES',
      'SEPARATED', 'SPACE', 'WITH', 'TASK', 'STARTING', 'DESTINATION', 'IN',
      'GROUP', 'EXCEPTIONS', 'INHERITING', 'REDEFINITION', 'AUTHORITY',
      'OBJECT', 'FIELD', 'TESTING', 'DURATION', 'SHORT', 'RISK', 'LEVEL', 'LOW',
      // 추가된 ABAP 키워드
      'PARAMETERS', 'TYPE', 'TYPE TABLE OF', 'STRUCTURE', 'INCLUDE', 'AT',
      'ENDAT', 'CHAIN', 'ENDCHAIN', 'FIELD-SYMBOLS', 'FIELD-SYMBOL',
      'ASSIGNING', 'CASTING', 'APPEND', 'MODIFY', 'COLLECT', 'READ TABLE',
      'TRANSPORTING', 'WHERE', 'INTO', 'REFERENCE INTO', 'CREATE OBJECT',
      'CALL METHOD', 'EXPORT', 'IMPORT', 'RECEIVING', 'RAISING',
      'CLASS-METHODS',
      'CLASS-METHOD', 'ALIASES', 'FOR', 'EVENT HANDLER',
      // FI 관련 키워드
      'BKPF', 'BSEG', 'GLT0', 'SKAT', 'SKB1', 'T001', 'T001B',
      // MM 관련 키워드
      'MARA', 'MARC', 'MARD', 'MBEW', 'T001W', 'T130', 'T156',
      // SD 관련 키워드
      'VBAK', 'VBAP', 'VBEP', 'TVAK', 'TVAP', 'TVGR',
    ],
    'built_in': [
      'SY-SUBRC',
      'SY-INDEX',
      'SY-DATUM',
      'SY-UZEIT',
      'SY-TCODE',
      'SY-UNAME',
      'SY-SYSID',
      'SY-MANDT',
      'SY-LANGU',
      'SY-HOST',
      'SY-SAPRL',
    ],
  },
  contains: [
    Mode(
      className: 'comment',
      begin: '\\*',
      end: '\$',
    ),
    Mode(
      className: 'string',
      begin: "'",
      end: "'",
    ),
    Mode(
      className: 'number',
      begin: '\\d+',
    ),
  ],
  refs: {},
);

// abap 언어를 HighlightView에서 사용 가능하도록 등록합니다.
void registerAbap() {
  Highlight().registerLanguage(abap, id: 'abap');
}
