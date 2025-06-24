/**
 * Welcome to Cloudflare Workers! This is your first worker.
 *
 * - Run `npm run dev` in your terminal to start a development server
 * - Open a browser tab at http://localhost:8787/ to see your worker in action
 * - Run `npm run deploy` to publish your worker
 *
 * Bind resources to your worker in `wrangler.jsonc`. After adding bindings, a type definition for the
 * `Env` object can be regenerated with `npm run cf-typegen`.
 *
 * Learn more at https://developers.cloudflare.com/workers/
 */

interface Env {
    DISCORD_BOT_TOKEN: string;
    DISCORD_CHANNEL_ID: string;
}

interface LocationParams {
    latitude: number;
    longitude: number;
    pinLatitude?: number;
    pinLongitude?: number;
    zoom?: number;
    message?: string;
}

function createGoogleMapsUrl(params: LocationParams): string {
    let url = `https://maps.google.com/maps?ll=${params.latitude},${params.longitude}`;

    if (params.pinLatitude !== undefined && params.pinLongitude !== undefined) {
        url += `&q=${params.pinLatitude},${params.pinLongitude}`;
    }

    if (params.zoom !== undefined) {
        url += `&z=${params.zoom}`;
    }

    return url;
}

function createCorsHeaders(origin: string | null): Record<string, string> {
    const allowedOrigins = [
        'https://survival-report.yuzu-juice.dev',
        'https://survival-report.netlify.app',
        'http://localhost:5173',
    ];

    const headers: Record<string, string> = {
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '86400',
    };

    if (origin && allowedOrigins.includes(origin)) {
        headers['Access-Control-Allow-Origin'] = origin;
    }

    return headers;
}

async function sendDiscordMessage(token: string, channelId: string, message: string): Promise<boolean> {
    try {
        const response = await fetch(`https://discord.com/api/v10/channels/${channelId}/messages`, {
            method: 'POST',
            headers: {
                'Authorization': `Bot ${token}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                content: message,
            }),
        });

        if (!response.ok) {
            const errorText = await response.text();
            console.error('Discord API error:', errorText);
        }

        return response.ok;
    } catch (error) {
        console.error('Discord message send error:', error);
        return false;
    }
}

export default {
    async fetch(request, env, ctx): Promise<Response> {
        const origin = request.headers.get('Origin');
        const corsHeaders = createCorsHeaders(origin);

        if (request.method === 'OPTIONS') {
            return new Response(null, {
                status: 204,
                headers: corsHeaders,
            });
        }

        console.log('Environment variables available:', {
            hasToken: !!env.DISCORD_BOT_TOKEN,
            hasChannelId: !!env.DISCORD_CHANNEL_ID
        });

        const url = new URL(request.url);
        switch (url.pathname) {
            case '/post':
                if (request.method !== 'POST') {
                    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
                        status: 405,
                        headers: { 'Content-Type': 'application/json', ...corsHeaders },
                    });
                }

                try {
                    const body = await request.json() as LocationParams;

                    if (typeof body.latitude !== 'number' || typeof body.longitude !== 'number') {
                        return new Response(JSON.stringify({
                            error: 'Missing required parameters: latitude and longitude must be numbers'
                        }), {
                            status: 500,
                            headers: { 'Content-Type': 'application/json', ...corsHeaders },
                        });
                    }

                    if (body.latitude < -90 || body.latitude > 90) {
                        return new Response(JSON.stringify({
                            error: 'Invalid latitude: must be between -90 and 90'
                        }), {
                            status: 500,
                            headers: { 'Content-Type': 'application/json', ...corsHeaders },
                        });
                    }

                    if (body.longitude < -180 || body.longitude > 180) {
                        return new Response(JSON.stringify({
                            error: 'Invalid longitude: must be between -180 and 180'
                        }), {
                            status: 500,
                            headers: { 'Content-Type': 'application/json', ...corsHeaders },
                        });
                    }

                    const googleMapsUrl = createGoogleMapsUrl(body);
                    const discordMessage = body.message
                        ? `${body.message}\n${googleMapsUrl}`
                        : googleMapsUrl;

                    const success = await sendDiscordMessage(
                        env.DISCORD_BOT_TOKEN,
                        env.DISCORD_CHANNEL_ID,
                        discordMessage
                    );

                    if (success) {
                        return new Response(JSON.stringify({
                            message: 'Location sent successfully!',
                            url: googleMapsUrl
                        }), {
                            status: 200,
                            headers: { 'Content-Type': 'application/json', ...corsHeaders },
                        });
                    } else {
                        return new Response(JSON.stringify({ error: 'Failed to send message' }), {
                            status: 500,
                            headers: { 'Content-Type': 'application/json', ...corsHeaders },
                        });
                    }
                } catch (error) {
                    return new Response(JSON.stringify({
                        error: 'Invalid JSON or missing parameters'
                    }), {
                        status: 500,
                        headers: { 'Content-Type': 'application/json', ...corsHeaders },
                    });
                }
            default:
                return new Response('Not Found', {
                    status: 404,
                    headers: corsHeaders
                });
        }
    },
} satisfies ExportedHandler<Env>;
