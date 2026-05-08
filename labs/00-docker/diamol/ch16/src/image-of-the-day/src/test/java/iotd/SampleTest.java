package iotd;

import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;

import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.MatcherAssert.assertThat;

public class SampleTest {

    @Test
    public void test() {
        
        int expected = 1;
        int actual = 1;
        assertThat(actual, is(equalTo(expected)));
    }
}