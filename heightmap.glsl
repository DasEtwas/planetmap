#ifndef PLANETMAP_HEIGHTMAP_GLSL_
#define PLANETMAP_HEIGHTMAP_GLSL_

struct Vertex {
    // Position of the vertex relative to Chunk.origin
    vec3 position;
    // Position of the vertex within the chunk
    vec2 texcoords;
};

struct Chunk {
    // Position within the chunk's depth in the quadtree
    uvec2 coords;
    // Depth in the quadtree
    uint depth;
    // Index of heightmap in the array texture.
    uint slot;
    // Position of the chunk relative to the center of the planet, as if on the +Z face of the
    // cubemap
    vec3 origin;
    // Level of detail of neighboring chunks
    uint neighborhood;
};

const uvec2 quad[6] = {
    {0, 0}, {1, 0}, {1, 1},
    {0, 0}, {1, 1}, {0, 1},
};

// Convert a point on a unit quad mapped to the current chunk into a point on the +Z surface of the unit sphere
vec3 unit_to_sphere(Chunk chunk, vec2 unit) {
    float side_length = 2.0 / pow(2, chunk.depth);
    return normalize(vec3((chunk.coords + unit) * side_length - 1.0, 1.0));
}

Vertex chunk_vertex(uint resolution, float radius, sampler2DArray heightmaps, Chunk chunk) {
    uint max_coord = resolution - 1;
    int quad_id = gl_VertexIndex / 6;
    // Integer vertex
    uvec2 quad_coord = (quad[gl_VertexIndex % 6] + uvec2(quad_id % resolution, quad_id / resolution));

    uvec4 neighborhood = uvec4(chunk.neighborhood >> 24, (chunk.neighborhood >> 16) & 0xFF, (chunk.neighborhood >> 8) & 0xFF, chunk.neighborhood & 0xFF);

    // Make some edges degenerate to line up with lower neighboring LoDs
    quad_coord.x &= (-1 << uint(quad_coord.y == 0) * neighborhood.y) & (-1 << uint(quad_coord.y == max_coord) * neighborhood.w);
    quad_coord.y &= (-1 << uint(quad_coord.x == 0) * neighborhood.x) & (-1 << uint(quad_coord.x == max_coord) * neighborhood.z);

    vec2 texcoords = vec2(quad_coord) / max_coord;

    float height = texture(heightmaps, vec3(texcoords, chunk.slot)).x;

    vec3 local_normal = unit_to_sphere(chunk, texcoords);

    Vertex result;
    result.position = (radius * local_normal - chunk.origin) + height * local_normal;
    result.texcoords = texcoords;
    
    return result;
}

#endif
