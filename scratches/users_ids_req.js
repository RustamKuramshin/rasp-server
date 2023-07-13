const http = require('http');

const options = {
    'method': 'POST',
    'hostname': 'localhost',
    'port': 3000,
    'path': '/v1/notifications/changed_users.json?access_token=BG4gvokTZ7jSUGhqhfi1lFvGr9V6oOdJGfVxfkv9tYIUNlxxHTtqGuZsqwox7ynz',
    'headers': {
        'Content-Type': 'application/json'
    },
    'maxRedirects': 20
};
const MAX_ID = 100;
const STEP = 10;

const usersIdsReq = async idsArr => {
    const req = http.request(options, function (res) {
        const chunks = [];

        res.on("data", function (chunk) {
            chunks.push(chunk);
        });

        res.on("end", function (chunk) {
            const body = Buffer.concat(chunks);
            console.log(body.toString());
        });

        res.on("error", function (error) {
            console.error(error);
        });
    });

    const postData = JSON.stringify({"users_ids": idsArr});

    req.write(postData);
    req.end(() => {
        console.log(`current IDs array: ${idsArr}`);
    });
};

(async () => {
    let idsArr = [];
    for (let i = 1; i < MAX_ID; i++) {
        idsArr.push(i);
        if (i%STEP === 0) {
            await usersIdsReq(idsArr);
            idsArr = [];
        }
    }
})();

