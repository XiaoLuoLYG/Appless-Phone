import localUnitTest from './LocalUnit.test';
import a2uiParserTest from './A2uiParser.test';
import localModelClientTest from './LocalModelClient.test';
import toolGatewayClientTest from './ToolGatewayClient.test';
import a2uiHomeStateTest from './A2uiHomeState.test';
import a2uiRenderDataTest from './A2uiRenderData.test';

export default function testsuite() {
  localUnitTest();
  a2uiParserTest();
  localModelClientTest();
  toolGatewayClientTest();
  a2uiHomeStateTest();
  a2uiRenderDataTest();
}
