export async function onRequest(context) {
    const url = new URL(context.request.url);
    const host = context.request.headers.get("host");

    // If the host does not start with www. and is not localhost (for development)
    if (host && !host.startsWith("www.") && !host.includes("localhost")) {
        url.hostname = `www.${host}`;
        return Response.redirect(url.toString(), 301);
    }

    return await context.next();
}
