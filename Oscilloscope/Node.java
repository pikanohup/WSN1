/*
 * Copyright (c) 2006 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA,
 * 94704.  Attention:  Intel License Inquiry.
 */

import java.util.*;

/**
 * Class holding all data received from a mote.
 */
class Node {
    /* The mote's identifier */
    int id;

    /* Data received from the mote. data[0] is the dataStart'th sample
       Indexes 0 through dataEnd - dataStart - 1 hold data.
       Samples are 16-bit unsigned numbers, -1 indicates missing data. */
    ArrayList<ControlMsg> controls = new ArrayList<ControlMsg>();

    Node(int _id) { id = _id; }

    void update(ControlMsg msg) {
        int dataStart;
        if (controls.size == 0) { dataStart = msg.get_time(); }
        int index = msg.get_time() - dataStart;
        if (index < 0) { return; }
        // Fill the list with empty data
        while (controls.size() <= index) { controls.add(null); }
        controls.set(index, msg);
    }

    /* Return value of sample x, or -1 for missing data */
    int getData(int x, int dataType) {
        try {
            if (dataType == 0) {
                return controls.get(x).get_light()[x];
            } else if (dataType == 1) {
                return controls.get(x).get_temperature()[x];
            } else if (dataType == 2) {
                return controls.get(x).get_humidity()[x];
            } else {
                return -1;
            }
        } catch (Exception e) {
            return -1;
        }
    }

    /* Return number of last known sample */
    int maxTime() { return controls.size(); }
}
