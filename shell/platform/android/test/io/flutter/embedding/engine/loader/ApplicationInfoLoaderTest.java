package io.flutter.embedding.engine.loader;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.mockito.Mockito.any;
import static org.mockito.Mockito.anyInt;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.res.Resources;
import android.content.res.XmlResourceParser;
import android.os.Bundle;
import android.security.NetworkSecurityPolicy;
import java.io.StringReader;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.stubbing.Answer;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.Implementation;
import org.robolectric.annotation.Implements;
import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlPullParserFactory;

@Config(manifest = Config.NONE)
@RunWith(RobolectricTestRunner.class)
public class ApplicationInfoLoaderTest {

  @Test
  public void itGeneratesCorrectApplicationInfoWithDefaultManifest() {
    FlutterApplicationInfo info = ApplicationInfoLoader.load(RuntimeEnvironment.application);
    assertNotNull(info);
    assertEquals("libapp.so", info.aotSharedLibraryName);
    assertEquals("vm_snapshot_data", info.vmSnapshotData);
    assertEquals("isolate_snapshot_data", info.isolateSnapshotData);
    assertEquals("flutter_assets", info.flutterAssetsDir);
    assertEquals("", info.domainNetworkPolicy);
    assertNull(info.nativeLibraryDir);
    assertEquals(true, info.clearTextPermitted);
    assertEquals(false, info.useEmbeddedView);
  }

  @Config(shadows = {ApplicationInfoLoaderTest.ShadowNetworkSecurityPolicy.class})
  @Test
  public void itVotesAgainstClearTextIfSecurityPolicySaysSo() {
    FlutterApplicationInfo info = ApplicationInfoLoader.load(RuntimeEnvironment.application);
    assertNotNull(info);
    assertEquals(false, info.clearTextPermitted);
  }

  @Implements(NetworkSecurityPolicy.class)
  public static class ShadowNetworkSecurityPolicy {
    @Implementation
    public boolean isCleartextTrafficPermitted() {
      return false;
    }
  }

  private Context generateMockContext(Bundle metadata, String networkPolicyXml) throws Exception {
    Context context = mock(Context.class);
    PackageManager packageManager = mock(PackageManager.class);
    ApplicationInfo applicationInfo = mock(ApplicationInfo.class);
    applicationInfo.metaData = metadata;
    Resources resources = mock(Resources.class);
    when(context.getPackageManager()).thenReturn(packageManager);
    when(context.getResources()).thenReturn(resources);
    when(packageManager.getApplicationInfo(any(String.class), any(int.class)))
        .thenReturn(applicationInfo);
    if (networkPolicyXml != null) {
      metadata.putInt(ApplicationInfoLoader.NETWORK_POLICY_METADATA_KEY, 5);
      doAnswer(invocationOnMock -> createMockResourceParser(networkPolicyXml))
          .when(resources)
          .getXml(5);
    }
    return context;
  }

  @Test
  public void itGeneratesCorrectApplicationInfoWithCustomValues() throws Exception {
    Bundle bundle = new Bundle();
    bundle.putString(ApplicationInfoLoader.PUBLIC_AOT_SHARED_LIBRARY_NAME, "testaot");
    bundle.putString(ApplicationInfoLoader.PUBLIC_VM_SNAPSHOT_DATA_KEY, "testvmsnapshot");
    bundle.putString(ApplicationInfoLoader.PUBLIC_ISOLATE_SNAPSHOT_DATA_KEY, "testisolatesnapshot");
    bundle.putString(ApplicationInfoLoader.PUBLIC_FLUTTER_ASSETS_DIR_KEY, "testassets");
    bundle.putBoolean("io.flutter.embedded_views_preview", true);
    Context context = generateMockContext(bundle, null);
    FlutterApplicationInfo info = ApplicationInfoLoader.load(context);
    assertNotNull(info);
    assertEquals("testaot", info.aotSharedLibraryName);
    assertEquals("testvmsnapshot", info.vmSnapshotData);
    assertEquals("testisolatesnapshot", info.isolateSnapshotData);
    assertEquals("testassets", info.flutterAssetsDir);
    assertNull(info.nativeLibraryDir);
    assertEquals("", info.domainNetworkPolicy);
    assertEquals(true, info.useEmbeddedView);
  }

  @Test
  public void itGeneratesCorrectNetworkPolicy() throws Exception {
    Bundle bundle = new Bundle();
    String networkPolicyXml =
        "<network-security-config>"
            + "<domain-config cleartextTrafficPermitted=\"false\">"
            + "<domain includeSubdomains=\"true\">secure.example.com</domain>"
            + "</domain-config>"
            + "</network-security-config>";
    Context context = generateMockContext(bundle, networkPolicyXml);
    FlutterApplicationInfo info = ApplicationInfoLoader.load(context);
    assertNotNull(info);
    assertEquals("[[\"secure.example.com\",true,false]]", info.domainNetworkPolicy);
  }

  @Test
  public void itHandlesBogusInformationInNetworkPolicy() throws Exception {
    Bundle bundle = new Bundle();
    String networkPolicyXml =
        "<network-security-config>"
            + "<domain-config cleartextTrafficPermitted=\"false\">"
            + "<domain includeSubdomains=\"true\">secure.example.com</domain>"
            + "<pin-set expiration=\"2018-01-01\">"
            + "<pin digest=\"SHA-256\">7HIpactkIAq2Y49orFOOQKurWxmmSFZhBCoQYcRhJ3Y=</pin>"
            + "<!-- backup pin -->"
            + "<pin digest=\"SHA-256\">fwza0LRMXouZHRC8Ei+4PyuldPDcf3UKgO/04cDM1oE=</pin>"
            + "</pin-set>"
            + "</domain-config>"
            + "</network-security-config>";
    Context context = generateMockContext(bundle, networkPolicyXml);
    FlutterApplicationInfo info = ApplicationInfoLoader.load(context);
    assertNotNull(info);
    assertEquals("[[\"secure.example.com\",true,false]]", info.domainNetworkPolicy);
  }

  @Test
  public void itHandlesNestedSubDomains() throws Exception {
    Bundle bundle = new Bundle();
    String networkPolicyXml =
        "<network-security-config>"
            + "<domain-config cleartextTrafficPermitted=\"true\">"
            + "<domain includeSubdomains=\"true\">example.com</domain>"
            + "<domain-config>"
            + "<domain includeSubdomains=\"true\">insecure.example.com</domain>"
            + "</domain-config>"
            + "<domain-config cleartextTrafficPermitted=\"false\">"
            + "<domain includeSubdomains=\"true\">secure.example.com</domain>"
            + "</domain-config>"
            + "</domain-config>"
            + "</network-security-config>";
    Context context = generateMockContext(bundle, networkPolicyXml);
    FlutterApplicationInfo info = ApplicationInfoLoader.load(context);
    assertNotNull(info);
    assertEquals(
        "[[\"example.com\",true,true],[\"insecure.example.com\",true,true],[\"secure.example.com\",true,false]]",
        info.domainNetworkPolicy);
  }

  // The following ridiculousness is needed because Android gives no way for us
  // to customize XmlResourceParser. We have to mock it and tie each method
  // we use to an actual Xml parser.
  private XmlResourceParser createMockResourceParser(String xml) throws Exception {
    final XmlPullParser xpp = XmlPullParserFactory.newInstance().newPullParser();
    xpp.setInput(new StringReader(xml));
    XmlResourceParser resourceParser = mock(XmlResourceParser.class);
    final Answer<Object> invokeMethodOnRealParser =
        invocation -> invocation.getMethod().invoke(xpp, invocation.getArguments());
    when(resourceParser.next()).thenAnswer(invokeMethodOnRealParser);
    when(resourceParser.getName()).thenAnswer(invokeMethodOnRealParser);
    when(resourceParser.getEventType()).thenAnswer(invokeMethodOnRealParser);
    when(resourceParser.getText()).thenAnswer(invokeMethodOnRealParser);
    when(resourceParser.getAttributeCount()).thenAnswer(invokeMethodOnRealParser);
    when(resourceParser.getAttributeName(anyInt())).thenAnswer(invokeMethodOnRealParser);
    when(resourceParser.getAttributeValue(anyInt())).thenAnswer(invokeMethodOnRealParser);
    when(resourceParser.getAttributeValue(any(String.class), any(String.class)))
        .thenAnswer(invokeMethodOnRealParser);
    when(resourceParser.getAttributeBooleanValue(
            any(String.class), any(String.class), any(Boolean.class)))
        .thenAnswer(
            invocation -> {
              Object[] args = invocation.getArguments();
              String result = xpp.getAttributeValue((String) args[0], (String) args[1]);
              if (result == null) {
                return (Boolean) args[2];
              }
              return Boolean.parseBoolean(result);
            });
    return resourceParser;
  }
}
