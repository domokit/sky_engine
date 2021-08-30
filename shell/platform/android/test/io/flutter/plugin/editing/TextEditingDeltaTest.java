package io.flutter.plugin.editing;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.mockito.Mockito.mock;

import android.view.View;
import dalvik.annotation.TestTarget;
import java.util.ArrayList;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@Config(manifest = Config.NONE)
@RunWith(RobolectricTestRunner.class)
public class TextEditingDeltaTest {
  @Before
  public void setUp() {
    MockitoAnnotations.initMocks(this);
  }

  @Test
  public void testInsertionTextEditingDeltaAtEndOfComposing() {
    // Here we are simulating inserting an "o" at the end of "hell".
    final CharSequence oldText = "hell";
    final CharSequence textAfterChange = "hello";

    final int oldComposingStart = 0;
    final int oldComposingEnd = 4;

    final int startOfReplacementText = 0;
    final int endOfReplacementText = textAfterChange.length();

    final int newSelectionStart = 5;
    final int newSelectionEnd = 5;
    final int newComposingStart = 0;
    final int newComposingEnd = 5;

    final TextEditingDelta delta =
        new TextEditingDelta(
            oldText,
            textAfterChange,
            oldComposingStart,
            oldComposingEnd,
            textAfterChange,
            startOfReplacementText,
            endOfReplacementText,
            newSelectionStart,
            newSelectionEnd,
            newComposingStart,
            newComposingEnd);

    assertEquals("TextEditingDeltaType.insertion", delta.getDeltaType());
    assertEquals(oldText, delta.getOldText());
    assertEquals("o", delta.getDeltaText());
    assertEquals(oldComposingEnd, delta.getDeltaStart());
    assertEquals(oldComposingEnd, delta.getDeltaEnd());
    assertEquals(newSelectionStart, delta.getSelectionStart());
    assertEquals(newSelectionEnd, delta.getSelectionEnd());
    assertEquals(newComposingStart, delta.getComposingStart());
    assertEquals(newComposingEnd, delta.getComposingEnd());
  }

  @Test
  public void testInsertionTextEditingDeltaInsideOfComposing() {
    // Here we are simulating inserting an "l" after the "l" in "helo".
    final CharSequence oldText = "helo";
    final CharSequence textAfterChange = "hello";

    final int oldComposingStart = 3;
    final int oldComposingEnd = 3;

    final int startOfReplacementText = 0;
    final int endOfReplacementText = textAfterChange.length();

    final int newSelectionStart = 4;
    final int newSelectionEnd = 4;
    final int newComposingStart = 4;
    final int newComposingEnd = 4;

    final TextEditingDelta delta =
        new TextEditingDelta(
            oldText,
            textAfterChange,
            oldComposingStart,
            oldComposingEnd,
            "l",
            startOfReplacementText,
            endOfReplacementText,
            newSelectionStart,
            newSelectionEnd,
            newComposingStart,
            newComposingEnd);

    assertEquals("TextEditingDeltaType.insertion", delta.getDeltaType());
    assertEquals(oldText, delta.getOldText());
    assertEquals("l", delta.getDeltaText());
    assertEquals(oldComposingEnd, delta.getDeltaStart());
    assertEquals(oldComposingEnd, delta.getDeltaEnd());
    assertEquals(newSelectionStart, delta.getSelectionStart());
    assertEquals(newSelectionEnd, delta.getSelectionEnd());
    assertEquals(newComposingStart, delta.getComposingStart());
    assertEquals(newComposingEnd, delta.getComposingEnd());
  }

  @Test
  public void testDeletionTextEditingDeltaAtEndOfComposing(){
    // Here we are simulating deleting an "o" at the end of "hello".
    final CharSequence oldText = "hello";
    final CharSequence textAfterChange = "hell";

    final int oldComposingStart = 0;
    final int oldComposingEnd = 5;

    final int startOfReplacementText = 0;
    final int endOfReplacementText = textAfterChange.length();

    final int newSelectionStart = 4;
    final int newSelectionEnd = 4;
    final int newComposingStart = 0;
    final int newComposingEnd = 4;

    final TextEditingDelta delta =
        new TextEditingDelta(
            oldText,
            textAfterChange,
            oldComposingStart,
            oldComposingEnd,
            textAfterChange,
            startOfReplacementText,
            endOfReplacementText,
            newSelectionStart,
            newSelectionEnd,
            newComposingStart,
            newComposingEnd);

    assertEquals("TextEditingDeltaType.deletion", delta.getDeltaType());
    assertEquals(oldText, delta.getOldText());
    assertEquals("o", delta.getDeltaText());
    assertEquals(oldComposingEnd, delta.getDeltaStart());
    assertEquals(oldComposingEnd, delta.getDeltaEnd());
    assertEquals(newSelectionStart, delta.getSelectionStart());
    assertEquals(newSelectionEnd, delta.getSelectionEnd());
    assertEquals(newComposingStart, delta.getComposingStart());
    assertEquals(newComposingEnd, delta.getComposingEnd());
  }

  @Test
  public void testDeletionTextEditingDeltaInsideComposing(){
    // Here we are simulating deleting an "e" in the world "hello".
    final CharSequence oldText = "hello";
    final CharSequence textAfterChange = "hllo";

    final int oldComposingStart = 2;
    final int oldComposingEnd = 2;

    final int startOfReplacementText = 0;
    final int endOfReplacementText = 0;

    final int newSelectionStart = 1;
    final int newSelectionEnd = 1;
    final int newComposingStart = 1;
    final int newComposingEnd = 1;

    final TextEditingDelta delta =
        new TextEditingDelta(
            oldText,
            textAfterChange,
            oldComposingStart,
            oldComposingEnd,
            "",
            startOfReplacementText,
            endOfReplacementText,
            newSelectionStart,
            newSelectionEnd,
            newComposingStart,
            newComposingEnd);

    assertEquals("TextEditingDeltaType.deletion", delta.getDeltaType());
    assertEquals(oldText, delta.getOldText());
    assertEquals("e", delta.getDeltaText());
    assertEquals(oldComposingEnd, delta.getDeltaStart());
    assertEquals(oldComposingEnd, delta.getDeltaEnd());
    assertEquals(newSelectionStart, delta.getSelectionStart());
    assertEquals(newSelectionEnd, delta.getSelectionEnd());
    assertEquals(newComposingStart, delta.getComposingStart());
    assertEquals(newComposingEnd, delta.getComposingEnd());
  }

  @Test
  public void testDeletionTextEditingDeltaForSelection(){
    // Here we are simulating deleting "llo" in the word "hello".
    final CharSequence oldText = "hello";
    final CharSequence textAfterChange = "he";

    final int oldComposingStart = 2;
    final int oldComposingEnd = 5;

    final int startOfReplacementText = 0;
    final int endOfReplacementText = 0;

    final int newSelectionStart = 2;
    final int newSelectionEnd = 2;
    final int newComposingStart = 0;
    final int newComposingEnd = 2;

    final TextEditingDelta delta =
        new TextEditingDelta(
            oldText,
            textAfterChange,
            oldComposingStart,
            oldComposingEnd,
            "",
            startOfReplacementText,
            endOfReplacementText,
            newSelectionStart,
            newSelectionEnd,
            newComposingStart,
            newComposingEnd);

    assertEquals("TextEditingDeltaType.deletion", delta.getDeltaType());
    assertEquals(oldText, delta.getOldText());
    assertEquals("llo", delta.getDeltaText());
    assertEquals(oldComposingEnd, delta.getDeltaStart());
    assertEquals(oldComposingEnd, delta.getDeltaEnd());
    assertEquals(newSelectionStart, delta.getSelectionStart());
    assertEquals(newSelectionEnd, delta.getSelectionEnd());
    assertEquals(newComposingStart, delta.getComposingStart());
    assertEquals(newComposingEnd, delta.getComposingEnd());
  }

  @Test
  public void testEqualityTextEditingDelta(){
    // Here we are simulating a change of the selection without a change to the text value.
    final CharSequence oldText = "hello";
    final CharSequence textAfterChange = "hello";

    final int oldComposingStart = 0;
    final int oldComposingEnd = 5;

    final int startOfReplacementText = 0;
    final int endOfReplacementText = textAfterChange.length();

    final int newSelectionStart = 3;
    final int newSelectionEnd = 3;
    final int newComposingStart = 0;
    final int newComposingEnd = 5;

    final TextEditingDelta delta =
        new TextEditingDelta(
            oldText,
            textAfterChange,
            oldComposingStart,
            oldComposingEnd,
            textAfterChange,
            startOfReplacementText,
            endOfReplacementText,
            newSelectionStart,
            newSelectionEnd,
            newComposingStart,
            newComposingEnd);

    assertEquals("TextEditingDeltaType.equality", delta.getDeltaType());
    assertEquals(oldText, delta.getOldText());
    assertEquals("", delta.getDeltaText());
    assertEquals(oldComposingEnd, delta.getDeltaStart());
    assertEquals(oldComposingEnd, delta.getDeltaEnd());
    assertEquals(newSelectionStart, delta.getSelectionStart());
    assertEquals(newSelectionEnd, delta.getSelectionEnd());
    assertEquals(newComposingStart, delta.getComposingStart());
    assertEquals(newComposingEnd, delta.getComposingEnd());
  }

  @Test
  public void testReplacementSameTextEditingDelta(){
    // Here we are simulating a replacement of a range of text that could for example happen
    // when the word "worfd" is autocorrected to the word "world".
    final CharSequence oldText = "worfd";
    final CharSequence textAfterChange = "world";

    final int oldComposingStart = 0;
    final int oldComposingEnd = 5;

    final int startOfReplacementText = 0;
    final int endOfReplacementText = textAfterChange.length();

    final int newSelectionStart = 5;
    final int newSelectionEnd = 5;
    final int newComposingStart = 0;
    final int newComposingEnd = 5;

    final TextEditingDelta delta =
        new TextEditingDelta(
            oldText,
            textAfterChange,
            oldComposingStart,
            oldComposingEnd,
            textAfterChange,
            startOfReplacementText,
            endOfReplacementText,
            newSelectionStart,
            newSelectionEnd,
            newComposingStart,
            newComposingEnd);

    assertEquals("TextEditingDeltaType.replacement", delta.getDeltaType());
    assertEquals(oldText, delta.getOldText());
    assertEquals("world", delta.getDeltaText());
    assertEquals(oldComposingEnd, delta.getDeltaStart());
    assertEquals(oldComposingEnd, delta.getDeltaEnd());
    assertEquals(newSelectionStart, delta.getSelectionStart());
    assertEquals(newSelectionEnd, delta.getSelectionEnd());
    assertEquals(newComposingStart, delta.getComposingStart());
    assertEquals(newComposingEnd, delta.getComposingEnd());
  }

  @Test
  public void testReplacementShorterTextEditingDelta(){
    // Here we are simulating a replacement of a range of text that could for example happen
    // when the word "world" is replaced with a single character "h".
    final CharSequence oldText = "world";
    final CharSequence textAfterChange = "h";

    final int oldComposingStart = 0;
    final int oldComposingEnd = 5;

    final int startOfReplacementText = 0;
    final int endOfReplacementText = textAfterChange.length();

    final int newSelectionStart = 1;
    final int newSelectionEnd = 1;
    final int newComposingStart = 0;
    final int newComposingEnd = 1;

    final TextEditingDelta delta =
        new TextEditingDelta(
            oldText,
            textAfterChange,
            oldComposingStart,
            oldComposingEnd,
            textAfterChange,
            startOfReplacementText,
            endOfReplacementText,
            newSelectionStart,
            newSelectionEnd,
            newComposingStart,
            newComposingEnd);

    assertEquals("TextEditingDeltaType.replacement", delta.getDeltaType());
    assertEquals(oldText, delta.getOldText());
    assertEquals(textAfterChange, delta.getDeltaText());
    assertEquals(oldComposingEnd, delta.getDeltaStart());
    assertEquals(oldComposingEnd, delta.getDeltaEnd());
    assertEquals(newSelectionStart, delta.getSelectionStart());
    assertEquals(newSelectionEnd, delta.getSelectionEnd());
    assertEquals(newComposingStart, delta.getComposingStart());
    assertEquals(newComposingEnd, delta.getComposingEnd());
  }

  @Test
  public void testReplacementLongerTextEditingDelta(){
    // Here we are simulating a replacement of a range of text that could for example happen
    // when the word "wolkin" is autocorrected to "walking".
    final CharSequence oldText = "wolkin";
    final CharSequence textAfterChange = "walking";

    final int oldComposingStart = 0;
    final int oldComposingEnd = 6;

    final int startOfReplacementText = 0;
    final int endOfReplacementText = textAfterChange.length();

    final int newSelectionStart = textAfterChange.length();
    final int newSelectionEnd = textAfterChange.length();
    final int newComposingStart = 0;
    final int newComposingEnd = textAfterChange.length();

    final TextEditingDelta delta =
        new TextEditingDelta(
            oldText,
            textAfterChange,
            oldComposingStart,
            oldComposingEnd,
            textAfterChange,
            startOfReplacementText,
            endOfReplacementText,
            newSelectionStart,
            newSelectionEnd,
            newComposingStart,
            newComposingEnd);

    assertEquals("TextEditingDeltaType.replacement", delta.getDeltaType());
    assertEquals(oldText, delta.getOldText());
    assertEquals(textAfterChange, delta.getDeltaText());
    assertEquals(oldComposingEnd, delta.getDeltaStart());
    assertEquals(oldComposingEnd, delta.getDeltaEnd());
    assertEquals(newSelectionStart, delta.getSelectionStart());
    assertEquals(newSelectionEnd, delta.getSelectionEnd());
    assertEquals(newComposingStart, delta.getComposingStart());
    assertEquals(newComposingEnd, delta.getComposingEnd());
  }

  @Test
  public void testSetNewComposingRegion() {
    final CharSequence oldText = "helfo";
    final CharSequence textAfterChange = "hello";

    final int oldComposingStart = 0;
    final int oldComposingEnd = 5;

    final int startOfReplacementText = 0;
    final int endOfReplacementText = textAfterChange.length();

    final int newSelectionStart = 5;
    final int newSelectionEnd = 5;
    final int newComposingStart = 0;
    final int newComposingEnd = 5;

    final TextEditingDelta delta =
        new TextEditingDelta(
            oldText,
            textAfterChange,
            oldComposingStart,
            oldComposingEnd,
            textAfterChange,
            startOfReplacementText,
            endOfReplacementText,
            newSelectionStart,
            newSelectionEnd,
            newComposingStart,
            newComposingEnd);

    assertEquals(0, delta.getNewComposingStart());
    assertEquals(5, delta.getNewComposingEnd());

    // (-1, -1) clears the composing region.
    delta.setNewComposingStart(-1);
    delta.setNewComposingEnd(-1);

    assertEquals(-1, delta.getNewComposingStart());
    assertEquals(-1, delta.getNewComposingEnd());

    delta.setNewComposingStart(0);
    delta.setNewComposingEnd(5);

    assertEquals(0, delta.getNewComposingStart());
    assertEquals(5, delta.getNewComposingEnd());
  }
}
